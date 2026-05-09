defmodule Holter.Identity.ApiTokensTest do
  use Holter.DataCase, async: false

  alias Ecto.Changeset
  alias Holter.Identity.ApiToken
  alias Holter.Identity.ApiTokens
  alias Holter.Identity.Memberships
  alias Holter.Repo
  alias Holter.Repo.Tenant

  describe "create_token/3" do
    test "returns plaintext shaped `hk_<urlsafe-random>` exactly once" do
      {user, workspace} = owner_and_workspace()

      {:ok, %ApiToken{}, plaintext} =
        ApiTokens.create_token(user, workspace, %{
          name: "CI",
          scopes: ["read:monitors"]
        })

      assert plaintext =~ ~r/^hk_[A-Za-z0-9_-]+$/
    end

    test "stores the SHA-256 digest of the plaintext, never the plaintext itself" do
      {user, workspace} = owner_and_workspace()

      {:ok, token, plaintext} =
        ApiTokens.create_token(user, workspace, %{name: "CI", scopes: ["read:monitors"]})

      assert token.hashed_value == :crypto.hash(:sha256, plaintext)
    end

    test "binds the token to the workspace" do
      {user, workspace} = owner_and_workspace()

      {:ok, token, _plaintext} =
        ApiTokens.create_token(user, workspace, %{name: "CI", scopes: ["read:monitors"]})

      assert token.workspace_id == workspace.id
    end

    test "binds the token to the user" do
      {user, workspace} = owner_and_workspace()

      {:ok, token, _plaintext} =
        ApiTokens.create_token(user, workspace, %{name: "CI", scopes: ["read:monitors"]})

      assert token.user_id == user.id
    end

    test "rejects creation when the user is not the workspace owner" do
      owner = user_fixture()
      member = user_fixture()
      workspace = workspace_fixture(owner: owner)
      grant_member_role(member, workspace, :member)

      assert {:error, :forbidden} =
               ApiTokens.create_token(member, workspace, %{
                 name: "CI",
                 scopes: ["read:monitors"]
               })
    end

    test "rejects creation when the user has no membership at all" do
      outsider = user_fixture()
      workspace = workspace_fixture()

      assert {:error, :forbidden} =
               ApiTokens.create_token(outsider, workspace, %{
                 name: "CI",
                 scopes: ["read:monitors"]
               })
    end

    test "surfaces the schema's empty-scope-list error" do
      {user, workspace} = owner_and_workspace()

      {:error, changeset} =
        ApiTokens.create_token(user, workspace, %{name: "CI", scopes: []})

      assert "must include at least one scope" in errors_on(changeset).scopes
    end

    test "accepts string-keyed attrs (UI form params come as strings)" do
      {user, workspace} = owner_and_workspace()

      assert {:ok, _token, _plaintext} =
               ApiTokens.create_token(user, workspace, %{
                 "name" => "CI",
                 "scopes" => ["read:monitors"]
               })
    end
  end

  describe "fetch_active_token_by_plaintext/1" do
    test "resolves the persisted row from a valid plaintext" do
      {user, workspace} = owner_and_workspace()
      {%ApiToken{id: token_id}, plaintext} = api_token_fixture(user, workspace)

      assert %ApiToken{id: ^token_id} = ApiTokens.fetch_active_token_by_plaintext(plaintext)
    end

    test "returns nil for a plaintext that doesn't exist" do
      assert ApiTokens.fetch_active_token_by_plaintext("hk_unknown") == nil
    end

    test "returns nil for a revoked token" do
      {user, workspace} = owner_and_workspace()
      {token, plaintext} = api_token_fixture(user, workspace)
      {:ok, _} = ApiTokens.revoke_token(token)

      assert ApiTokens.fetch_active_token_by_plaintext(plaintext) == nil
    end

    test "returns nil for an expired token" do
      {user, workspace} = owner_and_workspace()
      {token, plaintext} = api_token_fixture(user, workspace)
      past = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      Tenant.with_workspace!(workspace.id, fn ->
        token
        |> Changeset.change(expires_at: past)
        |> Repo.update!()
      end)

      assert ApiTokens.fetch_active_token_by_plaintext(plaintext) == nil
    end

    test "returns nil for nil input" do
      assert ApiTokens.fetch_active_token_by_plaintext(nil) == nil
    end

    test "preserves the scope list across the SECURITY DEFINER round-trip" do
      {user, workspace} = owner_and_workspace()

      {_token, plaintext} =
        api_token_fixture(user, workspace, scopes: ["read:logs", "read:metrics"])

      %ApiToken{scopes: scopes} = ApiTokens.fetch_active_token_by_plaintext(plaintext)

      assert Enum.sort(scopes) == ["read:logs", "read:metrics"]
    end
  end

  describe "revoke_token/1" do
    test "marks a live token as revoked" do
      {user, workspace} = owner_and_workspace()
      {token, _plaintext} = api_token_fixture(user, workspace)

      {:ok, revoked} = ApiTokens.revoke_token(token)

      assert %DateTime{} = revoked.revoked_at
    end

    test "is idempotent on an already-revoked token" do
      {user, workspace} = owner_and_workspace()
      {token, _plaintext} = api_token_fixture(user, workspace)
      {:ok, revoked} = ApiTokens.revoke_token(token)

      assert {:ok, ^revoked} = ApiTokens.revoke_token(revoked)
    end
  end

  describe "touch_last_used/2" do
    test "updates last_used_at to the supplied timestamp" do
      {user, workspace} = owner_and_workspace()
      {token, _plaintext} = api_token_fixture(user, workspace)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      :ok = ApiTokens.touch_last_used(token, now)

      reloaded = Tenant.with_workspace!(workspace.id, fn -> Repo.get!(ApiToken, token.id) end)

      assert reloaded.last_used_at == now
    end
  end

  describe "list_tokens_for_workspace/1" do
    test "returns tokens scoped to the workspace, newest first" do
      {user, workspace} = owner_and_workspace()
      {older, _} = api_token_fixture(user, workspace, name: "older")
      Process.sleep(1100)
      {newer, _} = api_token_fixture(user, workspace, name: "newer")

      ids = workspace |> ApiTokens.list_tokens_for_workspace() |> Enum.map(& &1.id)

      assert ids == [newer.id, older.id]
    end

    test "does not leak tokens from another workspace" do
      {user_a, ws_a} = owner_and_workspace()
      {user_b, ws_b} = owner_and_workspace()
      {token_a, _} = api_token_fixture(user_a, ws_a)
      {_token_b, _} = api_token_fixture(user_b, ws_b)

      ids = ws_a |> ApiTokens.list_tokens_for_workspace() |> Enum.map(& &1.id)

      assert ids == [token_a.id]
    end
  end

  defp owner_and_workspace do
    user = user_fixture()
    workspace = workspace_fixture(owner: user)
    {user, workspace}
  end

  defp grant_member_role(user, workspace, role) do
    {:ok, membership} = Memberships.create_default_membership(user, workspace)

    Tenant.with_user!(user, fn ->
      membership
      |> Changeset.change(role: role)
      |> Repo.update!()
    end)

    :ok
  end
end
