defmodule Holter.Integrations.Policies.IntegrationTest do
  use Holter.DataCase, async: true

  alias Holter.Integrations.IntegrationsContext
  alias Holter.Integrations.Policies.Integration, as: Policy
  alias Holter.Repo.Tenant

  describe ":read" do
    test "member is permitted" do
      {user, workspace} = workspace_with_role(:member)
      integration = create_policy_integration(%{workspace_id: workspace.id})

      assert :ok = Bodyguard.permit(Policy, :read, user, integration)
    end

    test "non-member is forbidden" do
      {_owner, workspace} = workspace_with_role(:owner)
      integration = create_policy_integration(%{workspace_id: workspace.id})

      assert {:error, :unauthorized} =
               Bodyguard.permit(Policy, :read, non_member_user(), integration)
    end
  end

  describe ":create" do
    test "member is permitted" do
      {user, workspace} = workspace_with_role(:member)

      assert :ok = Bodyguard.permit(Policy, :create, user, workspace)
    end

    test "admin is permitted" do
      {user, workspace} = workspace_with_role(:admin)

      assert :ok = Bodyguard.permit(Policy, :create, user, workspace)
    end

    test "non-member is forbidden" do
      {_owner, workspace} = workspace_with_role(:owner)

      assert {:error, :unauthorized} =
               Bodyguard.permit(Policy, :create, non_member_user(), workspace)
    end
  end

  describe ":update" do
    test "admin is permitted" do
      {user, workspace} = workspace_with_role(:admin)
      integration = create_policy_integration(%{workspace_id: workspace.id})

      assert :ok = Bodyguard.permit(Policy, :update, user, integration)
    end

    test "owner is permitted" do
      {user, workspace} = workspace_with_role(:owner)
      integration = create_policy_integration(%{workspace_id: workspace.id})

      assert :ok = Bodyguard.permit(Policy, :update, user, integration)
    end

    test "member is forbidden" do
      {user, workspace} = workspace_with_role(:member)
      integration = create_policy_integration(%{workspace_id: workspace.id})

      assert {:error, :unauthorized} = Bodyguard.permit(Policy, :update, user, integration)
    end

    test "non-member is forbidden" do
      {_owner, workspace} = workspace_with_role(:owner)
      integration = create_policy_integration(%{workspace_id: workspace.id})

      assert {:error, :unauthorized} =
               Bodyguard.permit(Policy, :update, non_member_user(), integration)
    end
  end

  describe ":delete" do
    test "admin is permitted" do
      {user, workspace} = workspace_with_role(:admin)
      integration = create_policy_integration(%{workspace_id: workspace.id})

      assert :ok = Bodyguard.permit(Policy, :delete, user, integration)
    end

    test "owner is permitted" do
      {user, workspace} = workspace_with_role(:owner)
      integration = create_policy_integration(%{workspace_id: workspace.id})

      assert :ok = Bodyguard.permit(Policy, :delete, user, integration)
    end

    test "member is forbidden" do
      {user, workspace} = workspace_with_role(:member)
      integration = create_policy_integration(%{workspace_id: workspace.id})

      assert {:error, :unauthorized} = Bodyguard.permit(Policy, :delete, user, integration)
    end

    test "non-member is forbidden" do
      {_owner, workspace} = workspace_with_role(:owner)
      integration = create_policy_integration(%{workspace_id: workspace.id})

      assert {:error, :unauthorized} =
               Bodyguard.permit(Policy, :delete, non_member_user(), integration)
    end
  end

  describe ":system actor" do
    test "system actor is permitted for any action on an integration" do
      {_owner, workspace} = workspace_with_role(:owner)
      integration = create_policy_integration(%{workspace_id: workspace.id})

      assert :ok = Bodyguard.permit(Policy, :read, :system, integration)
    end

    test "system actor is permitted to create" do
      {_owner, workspace} = workspace_with_role(:owner)

      assert :ok = Bodyguard.permit(Policy, :create, :system, workspace)
    end
  end

  defp create_policy_integration(attrs) do
    {owner, _ws} = workspace_with_role(:owner)

    attrs =
      Enum.into(attrs, %{
        provider: :google_ads,
        name: "Policy Test #{System.unique_integer([:positive])}",
        status: :active
      })

    Tenant.with_user!(owner, fn ->
      {:ok, integration} = IntegrationsContext.create(attrs)
      integration
    end)
  end
end
