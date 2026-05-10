defmodule Holter.Delivery.Policies.EmailChannelTest do
  use Holter.DataCase, async: true

  alias Holter.Delivery.EmailChannels
  alias Holter.Delivery.Models.EmailChannel
  alias Holter.Delivery.Policies.EmailChannel, as: Policy

  describe ":read" do
    test "member is permitted" do
      {user, workspace} = workspace_with_role(:member)
      channel = email_channel_fixture(workspace.id)

      assert :ok = Bodyguard.permit(Policy, :read, user, channel)
    end

    test "non-member is forbidden" do
      {_owner, workspace} = workspace_with_role(:owner)
      channel = email_channel_fixture(workspace.id)

      assert {:error, :unauthorized} =
               Bodyguard.permit(Policy, :read, non_member_user(), channel)
    end
  end

  describe ":update" do
    test "member is permitted" do
      {user, workspace} = workspace_with_role(:member)
      channel = email_channel_fixture(workspace.id)

      assert :ok = Bodyguard.permit(Policy, :update, user, channel)
    end
  end

  describe ":delete" do
    test "admin is permitted" do
      {user, workspace} = workspace_with_role(:admin)
      channel = email_channel_fixture(workspace.id)

      assert :ok = Bodyguard.permit(Policy, :delete, user, channel)
    end

    test "member is forbidden" do
      {user, workspace} = workspace_with_role(:member)
      channel = email_channel_fixture(workspace.id)

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
      mine = email_channel_fixture(workspace.id)

      {_other, other_workspace} = workspace_with_role(:owner)
      _theirs = email_channel_fixture(other_workspace.id)

      ids =
        EmailChannel
        |> Policy.scope(user)
        |> Holter.Repo.all()
        |> Enum.map(& &1.id)

      assert ids == [mine.id]
    end
  end

  defp email_channel_fixture(workspace_id) do
    {:ok, channel} =
      EmailChannels.create(%{
        workspace_id: workspace_id,
        name: "channel-#{System.unique_integer([:positive])}"
      })

    channel
  end
end
