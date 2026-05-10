defmodule Holter.Identity.Policies.ApiTokenTest do
  use Holter.DataCase, async: true

  alias Holter.Identity.Memberships
  alias Holter.Identity.Models.ApiToken
  alias Holter.Identity.Policies.ApiToken, as: Policy
  alias Holter.IdentityFixtures
  alias Holter.Repo
  alias Holter.Repo.Tenant

  describe ":read" do
    test "owner of the token is permitted" do
      {owner, workspace} = workspace_with_role(:owner)
      {token, _plaintext} = IdentityFixtures.api_token_fixture(owner, workspace)

      assert :ok = Bodyguard.permit(Policy, :read, owner, token)
    end

    test "workspace admin can read someone else's token" do
      {owner, workspace} = workspace_with_role(:owner)
      admin = join_workspace_with_role(workspace, :admin)
      {token, _plaintext} = IdentityFixtures.api_token_fixture(owner, workspace)

      assert :ok = Bodyguard.permit(Policy, :read, admin, token)
    end

    test "non-member is forbidden" do
      {owner, workspace} = workspace_with_role(:owner)
      {token, _plaintext} = IdentityFixtures.api_token_fixture(owner, workspace)

      assert {:error, :unauthorized} =
               Bodyguard.permit(Policy, :read, non_member_user(), token)
    end

    test "plain member who does not own the token is forbidden" do
      {owner, workspace} = workspace_with_role(:owner)
      peer = join_workspace_with_role(workspace, :member)
      {token, _plaintext} = IdentityFixtures.api_token_fixture(owner, workspace)

      assert {:error, :unauthorized} = Bodyguard.permit(Policy, :read, peer, token)
    end
  end

  describe ":revoke" do
    test "owner of the token is permitted" do
      {owner, workspace} = workspace_with_role(:owner)
      {token, _plaintext} = IdentityFixtures.api_token_fixture(owner, workspace)

      assert :ok = Bodyguard.permit(Policy, :revoke, owner, token)
    end

    test "workspace admin is permitted" do
      {owner, workspace} = workspace_with_role(:owner)
      admin = join_workspace_with_role(workspace, :admin)
      {token, _plaintext} = IdentityFixtures.api_token_fixture(owner, workspace)

      assert :ok = Bodyguard.permit(Policy, :revoke, admin, token)
    end
  end

  describe ":create" do
    test "member is permitted" do
      {user, workspace} = workspace_with_role(:member)

      assert :ok = Bodyguard.permit(Policy, :create, user, workspace)
    end

    test "non-member is forbidden" do
      {_owner, workspace} = workspace_with_role(:owner)

      assert {:error, :unauthorized} =
               Bodyguard.permit(Policy, :create, non_member_user(), workspace)
    end
  end

  describe "scope/2" do
    test "shows tokens the user owns in their workspace" do
      {owner, workspace} = workspace_with_role(:owner)
      {token, _plaintext} = IdentityFixtures.api_token_fixture(owner, workspace)

      ids =
        ApiToken
        |> Policy.scope(owner)
        |> Repo.all()
        |> Enum.map(& &1.id)

      assert ids == [token.id]
    end

    test "hides peers' tokens for plain members" do
      {owner, workspace} = workspace_with_role(:owner)
      peer = join_workspace_with_role(workspace, :member)
      {_token, _plaintext} = IdentityFixtures.api_token_fixture(owner, workspace)

      assert [] =
               ApiToken
               |> Policy.scope(peer)
               |> Repo.all()
    end

    test "admins can see peers' tokens" do
      {owner, workspace} = workspace_with_role(:owner)
      admin = join_workspace_with_role(workspace, :admin)
      {token, _plaintext} = IdentityFixtures.api_token_fixture(owner, workspace)

      ids =
        ApiToken
        |> Policy.scope(admin)
        |> Repo.all()
        |> Enum.map(& &1.id)

      assert token.id in ids
    end
  end

  defp join_workspace_with_role(workspace, role) do
    user = IdentityFixtures.user_fixture()
    {:ok, _membership} = Memberships.create_default_membership(user, workspace)
    coerce_role(user, workspace, role)
    user
  end

  defp coerce_role(_user, _workspace, :owner), do: :ok

  defp coerce_role(user, workspace, role) do
    membership = Memberships.get_membership(user, workspace)

    Tenant.with_user!(user, fn ->
      membership
      |> Ecto.Changeset.change(role: role)
      |> Repo.update!()
    end)
  end
end
