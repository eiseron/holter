defmodule Holter.Identity.TokenTest do
  use Holter.DataCase, async: true

  alias Holter.Identity.Token

  defp future(seconds_from_now) do
    DateTime.utc_now()
    |> DateTime.add(seconds_from_now, :second)
    |> DateTime.truncate(:second)
  end

  defp valid_token_attrs(user, overrides \\ %{}) do
    Enum.into(overrides, %{
      user_id: user.id,
      type: :verify_email,
      hashed_value: Token.compute_hash("plaintext-#{System.unique_integer([:positive])}"),
      expires_at: future(3600)
    })
  end

  describe "compute_hash/1" do
    test "produces a 32-byte SHA-256 digest" do
      digest = Token.compute_hash("any-plaintext-token")

      assert byte_size(digest) == 32
    end

    test "is deterministic for identical input" do
      assert Token.compute_hash("same-input") == Token.compute_hash("same-input")
    end

    test "diverges across distinct inputs" do
      refute Token.compute_hash("alpha") == Token.compute_hash("beta")
    end
  end

  describe "expired?/2" do
    test "returns false when expiration is strictly in the future" do
      token = %Token{expires_at: future(60)}

      refute Token.expired?(token, DateTime.utc_now())
    end

    test "returns true when expiration is in the past" do
      token = %Token{expires_at: future(-60)}

      assert Token.expired?(token, DateTime.utc_now())
    end

    test "returns true at the exact expiration moment (TTL is exclusive)" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      token = %Token{expires_at: now}

      assert Token.expired?(token, now)
    end
  end

  describe "consumed?/1" do
    test "is false when used_at is nil" do
      refute Token.consumed?(%Token{used_at: nil})
    end

    test "is true once used_at is stamped" do
      assert Token.consumed?(%Token{used_at: DateTime.utc_now()})
    end
  end

  describe "insert_changeset/1" do
    test "persists a valid token row" do
      user = user_fixture()

      assert {:ok, _} =
               valid_token_attrs(user)
               |> Token.insert_changeset()
               |> Repo.insert()
    end

    test "rejects unknown token types" do
      user = user_fixture()

      changeset =
        valid_token_attrs(user, %{type: :totally_invalid})
        |> Token.insert_changeset()

      assert "is invalid" in errors_on(changeset).type
    end

    test "requires the four core fields" do
      changeset = Token.insert_changeset(%{})

      missing = errors_on(changeset) |> Map.keys() |> MapSet.new()

      assert MapSet.subset?(MapSet.new([:user_id, :type, :hashed_value, :expires_at]), missing)
    end

    test "rejects orphan tokens whose user does not exist" do
      attrs = valid_token_attrs(%{id: Ecto.UUID.generate()})

      {:error, changeset} =
        attrs
        |> Token.insert_changeset()
        |> Repo.insert()

      assert "does not exist" in errors_on(changeset).user
    end

    test "deletes tokens when their user is deleted (FK on_delete: :delete_all)" do
      user = user_fixture()

      {:ok, token} =
        valid_token_attrs(user)
        |> Token.insert_changeset()
        |> Repo.insert()

      Repo.delete!(user)

      refute Repo.get(Token, token.id)
    end

    test "stores the hashed_value as raw bytes (never plaintext)" do
      user = user_fixture()
      hash = Token.compute_hash("plaintext-secret")

      {:ok, token} =
        valid_token_attrs(user, %{hashed_value: hash})
        |> Token.insert_changeset()
        |> Repo.insert()

      assert token.hashed_value == hash
    end
  end

  describe "consume_changeset/2" do
    test "stamps used_at to the supplied moment, preventing replay" do
      user = user_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, token} =
        valid_token_attrs(user)
        |> Token.insert_changeset()
        |> Repo.insert()

      {:ok, consumed} =
        token
        |> Token.consume_changeset(now)
        |> Repo.update()

      assert consumed.used_at == now
    end
  end
end
