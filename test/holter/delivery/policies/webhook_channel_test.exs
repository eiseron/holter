defmodule Holter.Delivery.Policies.WebhookChannelTest do
  use Holter.DataCase, async: true

  alias Holter.Delivery.Models.WebhookChannel
  alias Holter.Delivery.Policies.WebhookChannel, as: Policy
  alias Holter.Delivery.WebhookChannels

  describe ":read" do
    test "member is permitted" do
      {user, workspace} = workspace_with_role(:member)
      channel = webhook_channel_fixture(workspace.id)

      assert :ok = Bodyguard.permit(Policy, :read, user, channel)
    end

    test "non-member is forbidden" do
      {_owner, workspace} = workspace_with_role(:owner)
      channel = webhook_channel_fixture(workspace.id)

      assert {:error, :unauthorized} =
               Bodyguard.permit(Policy, :read, non_member_user(), channel)
    end
  end

  describe ":update" do
    test "member can update" do
      {user, workspace} = workspace_with_role(:member)
      channel = webhook_channel_fixture(workspace.id)

      assert :ok = Bodyguard.permit(Policy, :update, user, channel)
    end
  end

  describe ":test" do
    test "member can dispatch a test send" do
      {user, workspace} = workspace_with_role(:member)
      channel = webhook_channel_fixture(workspace.id)

      assert :ok = Bodyguard.permit(Policy, :test, user, channel)
    end
  end

  describe ":delete" do
    test "admin is permitted" do
      {user, workspace} = workspace_with_role(:admin)
      channel = webhook_channel_fixture(workspace.id)

      assert :ok = Bodyguard.permit(Policy, :delete, user, channel)
    end

    test "member is forbidden" do
      {user, workspace} = workspace_with_role(:member)
      channel = webhook_channel_fixture(workspace.id)

      assert {:error, :unauthorized} = Bodyguard.permit(Policy, :delete, user, channel)
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
    test "limits to channels in user workspaces" do
      {user, workspace} = workspace_with_role(:member)
      mine = webhook_channel_fixture(workspace.id)

      {_other, other_workspace} = workspace_with_role(:owner)
      _theirs = webhook_channel_fixture(other_workspace.id)

      ids =
        WebhookChannel
        |> Policy.scope(user)
        |> Holter.Repo.all()
        |> Enum.map(& &1.id)

      assert ids == [mine.id]
    end
  end

  defp webhook_channel_fixture(workspace_id) do
    {:ok, channel} =
      WebhookChannels.create(%{
        workspace_id: workspace_id,
        name: "channel-#{System.unique_integer([:positive])}",
        url: "https://example.com/hook"
      })

    channel
  end
end
