defmodule Holter.Identity.ApiTokenTest do
  use ExUnit.Case, async: true

  alias Holter.Identity.Models.ApiToken

  describe "compute_hash/1" do
    test "produces a 32-byte SHA-256 digest" do
      digest = ApiToken.compute_hash("hk_anything")

      assert byte_size(digest) == 32
    end

    test "is deterministic for the same plaintext" do
      assert ApiToken.compute_hash("hk_x") == ApiToken.compute_hash("hk_x")
    end

    test "differs across plaintexts" do
      refute ApiToken.compute_hash("hk_a") == ApiToken.compute_hash("hk_b")
    end
  end

  describe "active?/2" do
    test "is active when not revoked and no expiry" do
      assert ApiToken.active?(%ApiToken{revoked_at: nil, expires_at: nil}, now())
    end

    test "is active when not revoked and expiry is in the future" do
      future = DateTime.add(now(), 3600, :second)

      assert ApiToken.active?(%ApiToken{revoked_at: nil, expires_at: future}, now())
    end

    test "is inactive when revoked" do
      refute ApiToken.active?(%ApiToken{revoked_at: now(), expires_at: nil}, now())
    end

    test "is inactive when expired" do
      past = DateTime.add(now(), -1, :second)

      refute ApiToken.active?(%ApiToken{revoked_at: nil, expires_at: past}, now())
    end

    test "is inactive at the exact expiry second (boundary)" do
      same = now()

      refute ApiToken.active?(%ApiToken{revoked_at: nil, expires_at: same}, same)
    end
  end

  describe "has_scope?/2" do
    test "is true when the scope is in the token's scopes list" do
      assert ApiToken.has_scope?(
               %ApiToken{scopes: ["read:monitors", "write:monitors"]},
               "read:monitors"
             )
    end

    test "is false when the scope is missing" do
      refute ApiToken.has_scope?(%ApiToken{scopes: ["read:monitors"]}, "write:monitors")
    end

    test "treats scope strings as exact matches (no prefix-broadening)" do
      refute ApiToken.has_scope?(%ApiToken{scopes: ["read:monitors"]}, "read:")
    end
  end

  describe "insert_changeset/1" do
    test "is valid with a name, scopes, hashed_value, and FKs" do
      changeset = ApiToken.insert_changeset(valid_attrs())

      assert changeset.valid?
    end

    test "requires a name" do
      changeset = ApiToken.insert_changeset(Map.delete(valid_attrs(), :name))

      assert "can't be blank" in errors(changeset).name
    end

    test "treats a missing :scopes attr as `must include at least one scope`" do
      changeset = ApiToken.insert_changeset(Map.delete(valid_attrs(), :scopes))

      assert "must include at least one scope" in errors(changeset).scopes
    end

    test "rejects a name longer than 64 characters" do
      changeset = ApiToken.insert_changeset(%{valid_attrs() | name: String.duplicate("x", 65)})

      assert Enum.any?(errors(changeset).name, &String.contains?(&1, "should be at most"))
    end

    test "requires at least one scope" do
      changeset = ApiToken.insert_changeset(%{valid_attrs() | scopes: []})

      assert "must include at least one scope" in errors(changeset).scopes
    end

    test "rejects unknown scope strings" do
      changeset = ApiToken.insert_changeset(%{valid_attrs() | scopes: ["read:everything"]})

      assert Enum.any?(
               errors(changeset).scopes,
               &String.starts_with?(&1, "contains invalid scopes")
             )
    end

    test "rejects non-list scopes" do
      changeset = ApiToken.insert_changeset(%{valid_attrs() | scopes: "read:monitors"})

      refute changeset.valid?
    end
  end

  describe "revoke_changeset/2" do
    test "stamps revoked_at" do
      now = now()

      changeset = ApiToken.revoke_changeset(%ApiToken{}, now)

      assert Ecto.Changeset.get_change(changeset, :revoked_at) == now
    end
  end

  describe "Inspect redaction" do
    test "hashed_value is omitted from inspect output" do
      token = %ApiToken{hashed_value: <<1, 2, 3>>}

      refute inspect(token) =~ "hashed_value"
      refute inspect(token) =~ Base.encode16(<<1, 2, 3>>)
    end
  end

  defp valid_attrs do
    %{
      user_id: Ecto.UUID.generate(),
      workspace_id: Ecto.UUID.generate(),
      name: "CI",
      hashed_value: ApiToken.compute_hash("hk_anything"),
      scopes: ["read:monitors"]
    }
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)

  defp errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
