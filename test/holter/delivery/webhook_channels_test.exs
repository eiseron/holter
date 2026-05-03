defmodule Holter.Delivery.WebhookChannelsTest do
  use Holter.DataCase, async: true

  import Holter.MonitoringFixtures

  alias Holter.Delivery.WebhookChannel
  alias Holter.Delivery.WebhookChannels

  describe "create/1" do
    test "stores name, workspace_id and url from the attrs" do
      ws = workspace_fixture()
      ws_id = ws.id

      assert {:ok,
              %WebhookChannel{
                workspace_id: ^ws_id,
                name: "Ops Hook",
                url: "https://hooks.example.com/notify"
              }} =
               WebhookChannels.create(%{
                 workspace_id: ws.id,
                 name: "Ops Hook",
                 url: "https://hooks.example.com/notify"
               })
    end

    test "auto-generates a signing token" do
      ws = workspace_fixture()

      {:ok, channel} =
        WebhookChannels.create(%{
          workspace_id: ws.id,
          name: "Hook",
          url: "https://hooks.example.com/h"
        })

      assert is_binary(channel.signing_token)
    end

    test "rejects an invalid URL with a semantic error message" do
      ws = workspace_fixture()

      {:error, cs} =
        WebhookChannels.create(%{workspace_id: ws.id, name: "Bad", url: "not-a-url"})

      assert "must be a valid http or https URL" in errors_on(cs).url
    end

    test "requires workspace_id" do
      {:error, cs} = WebhookChannels.create(%{name: "X", url: "https://example.com/h"})
      assert "can't be blank" in errors_on(cs).workspace_id
    end

    test "requires name" do
      ws = workspace_fixture()

      {:error, cs} =
        WebhookChannels.create(%{workspace_id: ws.id, url: "https://example.com/h"})

      assert "can't be blank" in errors_on(cs).name
    end

    test "requires url" do
      ws = workspace_fixture()
      {:error, cs} = WebhookChannels.create(%{workspace_id: ws.id, name: "Hook"})
      assert "can't be blank" in errors_on(cs).url
    end
  end

  describe "list/1" do
    test "returns workspace channels sorted by name" do
      ws = workspace_fixture()
      other = workspace_fixture()

      {:ok, alpha} =
        WebhookChannels.create(%{
          workspace_id: ws.id,
          name: "Alpha",
          url: "https://hooks.example.com/a"
        })

      {:ok, _bravo_other_ws} =
        WebhookChannels.create(%{
          workspace_id: other.id,
          name: "Bravo",
          url: "https://hooks.example.com/b"
        })

      {:ok, charlie} =
        WebhookChannels.create(%{
          workspace_id: ws.id,
          name: "Charlie",
          url: "https://hooks.example.com/c"
        })

      assert Enum.map(WebhookChannels.list(ws.id), & &1.id) == [alpha.id, charlie.id]
    end
  end

  describe "count/1" do
    test "counts channels in the workspace only" do
      ws = workspace_fixture()
      other = workspace_fixture()

      {:ok, _} =
        WebhookChannels.create(%{
          workspace_id: ws.id,
          name: "A",
          url: "https://hooks.example.com/a"
        })

      {:ok, _} =
        WebhookChannels.create(%{
          workspace_id: other.id,
          name: "B",
          url: "https://hooks.example.com/b"
        })

      assert WebhookChannels.count(ws.id) == 1
    end
  end

  describe "get/1" do
    test "returns {:error, :not_found} for unknown ids" do
      assert {:error, :not_found} =
               WebhookChannels.get("00000000-0000-0000-0000-000000000000")
    end

    test "returns the matching channel for known ids" do
      {:ok, created} = create_channel()
      {:ok, fetched} = WebhookChannels.get(created.id)
      assert fetched.id == created.id
    end
  end

  describe "get!/1" do
    test "raises for unknown ids" do
      assert_raise Ecto.NoResultsError, fn ->
        WebhookChannels.get!("00000000-0000-0000-0000-000000000000")
      end
    end
  end

  describe "update/2" do
    test "updates the URL" do
      {:ok, channel} = create_channel()

      {:ok, updated} =
        WebhookChannels.update(channel, %{url: "https://hooks.example.com/new"})

      assert updated.url == "https://hooks.example.com/new"
    end

    test "preserves the signing token" do
      {:ok, channel} = create_channel()
      original_token = channel.signing_token

      {:ok, updated} =
        WebhookChannels.update(channel, %{url: "https://hooks.example.com/new"})

      assert updated.signing_token == original_token
    end
  end

  describe "delete/1" do
    test "removes the channel from the workspace" do
      {:ok, channel} = create_channel()
      {:ok, _} = WebhookChannels.delete(channel)
      assert {:error, :not_found} = WebhookChannels.get(channel.id)
    end
  end

  describe "regenerate_signing_token/1" do
    test "rotates the signing token to a fresh value" do
      {:ok, channel} = create_channel()
      original = channel.signing_token

      {:ok, rotated} = WebhookChannels.regenerate_signing_token(channel)
      assert rotated.signing_token != original
    end
  end

  describe "touch_test_dispatched_at/2" do
    test "stamps last_test_dispatched_at on the row" do
      {:ok, channel} = create_channel()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      :ok = WebhookChannels.touch_test_dispatched_at(channel, now)

      assert DateTime.compare(WebhookChannels.get!(channel.id).last_test_dispatched_at, now) ==
               :eq
    end
  end

  defp create_channel do
    ws = workspace_fixture()

    WebhookChannels.create(%{
      workspace_id: ws.id,
      name: "Hook",
      url: "https://hooks.example.com/hook"
    })
  end
end
