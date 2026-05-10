defmodule Holter.AuthorizationAssertions do
  @moduledoc """
  Test assertions and fixtures for `Holter.Authorization`.

  Exposed via the `Holter.DataCase` `using` block so every data test
  can call `assert_authorized/3`, `assert_forbidden/3`, and
  `workspace_with_role/1` without explicit imports.
  """

  import ExUnit.Assertions

  alias Ecto.Changeset
  alias Holter.Authorization
  alias Holter.Identity.Memberships
  alias Holter.IdentityFixtures
  alias Holter.MonitoringFixtures
  alias Holter.Repo
  alias Holter.Repo.Tenant

  def assert_authorized(actor, action, subject) do
    assert :ok == Authorization.authorize(actor, action, subject)
  end

  def assert_forbidden(actor, action, subject) do
    assert {:error, :forbidden} == Authorization.authorize(actor, action, subject)
  end

  def workspace_with_role(role) when role in [:owner, :admin, :member] do
    user = IdentityFixtures.user_fixture()
    workspace = MonitoringFixtures.workspace_fixture(owner: user)
    coerce_membership_role(user, workspace, role)
    {user, workspace}
  end

  def non_member_user, do: IdentityFixtures.user_fixture()

  defp coerce_membership_role(_user, _workspace, :owner), do: :ok

  defp coerce_membership_role(user, workspace, role) do
    membership = Memberships.get_membership(user, workspace)

    Tenant.with_user!(user, fn ->
      membership
      |> Changeset.change(role: role)
      |> Repo.update!()
    end)
  end
end
