defmodule Holter.Delivery.ProfilesTest do
  use Holter.DataCase, async: true

  alias Holter.Delivery.{EmailChannels, Profiles, WebhookChannels}
  alias Holter.Delivery.Models.{EmailChannel, WebhookChannel}

  describe "get_for_workspace!/1" do
    test "returns the delivery profile created alongside the workspace, keyed on workspace_id" do
      ws = workspace_fixture()
      ws_id = ws.id

      assert %Holter.Delivery.Models.WorkspaceProfile{
               workspace_id: ^ws_id,
               max_channels: 2
             } = Profiles.get_for_workspace!(ws.id)
    end

    test "raises when the workspace has no delivery profile" do
      assert_raise Ecto.NoResultsError, fn ->
        Profiles.get_for_workspace!(Ecto.UUID.generate())
      end
    end
  end

  describe "update_profile/2" do
    test "persists a higher max_channels" do
      profile = Profiles.get_for_workspace!(workspace_fixture().id)

      assert {:ok, %{max_channels: 25}} = Profiles.update_profile(profile, %{max_channels: 25})
    end

    test "rejects max_channels < 1 with a semantic error" do
      profile = Profiles.get_for_workspace!(workspace_fixture().id)
      {:error, cs} = Profiles.update_profile(profile, %{max_channels: 0})

      assert "must be greater than or equal to 1" in errors_on(cs).max_channels
    end
  end

  describe "schema-level bypass guard" do
    test "Repo.insert on WebhookChannel.changeset is rejected at quota" do
      ws = workspace_fixture(%{max_channels: 1})

      {:ok, _} =
        WebhookChannels.create(%{
          workspace_id: ws.id,
          name: "First",
          url: "https://hooks.example.com/a"
        })

      {:error, changeset} =
        %WebhookChannel{}
        |> WebhookChannel.changeset(%{
          workspace_id: ws.id,
          name: "Second",
          url: "https://hooks.example.com/b"
        })
        |> Holter.Repo.insert()

      {_message, opts} = changeset.errors[:workspace_id]
      assert Keyword.get(opts, :code) == :channel_quota_reached
    end

    test "Repo.insert on EmailChannel.changeset is rejected at quota" do
      ws = workspace_fixture(%{max_channels: 1})
      {:ok, _} = EmailChannels.create(%{workspace_id: ws.id, name: "First"})

      {:error, changeset} =
        %EmailChannel{}
        |> EmailChannel.changeset(%{
          workspace_id: ws.id,
          name: "Second"
        })
        |> Holter.Repo.insert()

      {_message, opts} = changeset.errors[:workspace_id]
      assert Keyword.get(opts, :code) == :channel_quota_reached
    end
  end

  describe "at_channel_quota?/1" do
    test "false on a fresh workspace (count 0 < default cap 2)" do
      ws = workspace_fixture()

      refute Profiles.at_channel_quota?(ws.id)
    end

    test "true once webhook+email counts combined reach max_channels" do
      ws = workspace_fixture(%{max_channels: 2})

      {:ok, _} =
        WebhookChannels.create(%{
          workspace_id: ws.id,
          name: "A",
          url: "https://hooks.example.com/a"
        })

      {:ok, _} = EmailChannels.create(%{workspace_id: ws.id, name: "B"})

      assert Profiles.at_channel_quota?(ws.id)
    end

    test "counts webhook + email combined (single cap across both subtypes)" do
      ws = workspace_fixture(%{max_channels: 3})

      {:ok, _} = EmailChannels.create(%{workspace_id: ws.id, name: "E1"})
      {:ok, _} = EmailChannels.create(%{workspace_id: ws.id, name: "E2"})

      refute Profiles.at_channel_quota?(ws.id)

      {:ok, _} =
        WebhookChannels.create(%{
          workspace_id: ws.id,
          name: "W1",
          url: "https://hooks.example.com/x"
        })

      assert Profiles.at_channel_quota?(ws.id)
    end
  end
end
