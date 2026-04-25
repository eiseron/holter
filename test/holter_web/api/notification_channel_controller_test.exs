defmodule HolterWeb.Api.NotificationChannelControllerTest do
  use HolterWeb.ConnCase
  use Oban.Testing, repo: Holter.Repo

  import OpenApiSpex.TestAssertions

  alias Holter.Delivery
  alias HolterWeb.Api.ApiSpec

  setup %{conn: conn} do
    workspace = workspace_fixture(%{name: "Test Workspace", slug: "test-workspace"})
    api_spec = ApiSpec.spec()

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")

    {:ok, conn: conn, workspace: workspace, api_spec: api_spec}
  end

  defp json_post(conn, path, body), do: post(conn, path, Jason.encode!(body))
  defp json_put(conn, path, body), do: put(conn, path, Jason.encode!(body))

  defp channel_fixture(workspace_id, attrs \\ %{}) do
    {:ok, channel} =
      Delivery.create_channel(
        Map.merge(
          %{
            workspace_id: workspace_id,
            name: "Test Webhook",
            type: :webhook,
            target: "https://example.com/hook"
          },
          attrs
        )
      )

    channel
  end

  describe "GET /api/v1/workspaces/:workspace_slug/notification_channels" do
    test "returns list of channels for workspace", %{
      conn: conn,
      workspace: workspace,
      api_spec: spec
    } do
      channel_fixture(workspace.id)

      conn = get(conn, ~p"/api/v1/workspaces/#{workspace.slug}/notification_channels")
      body = json_response(conn, 200)

      assert %{"data" => [_]} = body
      assert_schema(body, "NotificationChannelList", spec)
    end

    test "returns empty list when workspace has no channels", %{conn: conn, workspace: workspace} do
      conn = get(conn, ~p"/api/v1/workspaces/#{workspace.slug}/notification_channels")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns 404 for unknown workspace slug", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/workspaces/does-not-exist/notification_channels")
      assert json_response(conn, 404)
    end
  end

  describe "GET /api/v1/notification_channels/:id" do
    test "returns the channel", %{conn: conn, workspace: workspace, api_spec: spec} do
      channel = channel_fixture(workspace.id)

      conn = get(conn, ~p"/api/v1/notification_channels/#{channel.id}")
      body = json_response(conn, 200)

      assert body["data"]["id"] == channel.id
      assert_schema(body, "NotificationChannelResponse", spec)
    end

    test "returns 404 for unknown channel id", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/notification_channels/00000000-0000-0000-0000-000000000000")
      assert json_response(conn, 404)
    end
  end

  describe "POST /api/v1/workspaces/:workspace_slug/notification_channels" do
    @valid_attrs %{name: "My Hook", type: "webhook", target: "https://hooks.example.com/notify"}

    test "creates a channel and returns 201", %{conn: conn, workspace: workspace, api_spec: spec} do
      conn =
        json_post(
          conn,
          ~p"/api/v1/workspaces/#{workspace.slug}/notification_channels",
          @valid_attrs
        )

      body = json_response(conn, 201)

      assert body["data"]["name"] == "My Hook"
      assert_schema(body, "NotificationChannelResponse", spec)
    end

    test "returns 422 for missing required fields", %{conn: conn, workspace: workspace} do
      conn =
        json_post(conn, ~p"/api/v1/workspaces/#{workspace.slug}/notification_channels", %{
          name: "Bad"
        })

      assert json_response(conn, 422)
    end

    test "returns 422 for invalid webhook target URL", %{conn: conn, workspace: workspace} do
      conn =
        json_post(conn, ~p"/api/v1/workspaces/#{workspace.slug}/notification_channels", %{
          name: "Bad Hook",
          type: "webhook",
          target: "not-a-url"
        })

      resp = json_response(conn, 422)
      assert resp["error"]["code"] == "validation_failed"
    end
  end

  describe "PUT /api/v1/notification_channels/:id" do
    test "updates the channel name", %{conn: conn, workspace: workspace, api_spec: spec} do
      channel = channel_fixture(workspace.id)

      conn =
        json_put(conn, ~p"/api/v1/notification_channels/#{channel.id}", %{name: "Updated Name"})

      body = json_response(conn, 200)

      assert body["data"]["name"] == "Updated Name"
      assert_schema(body, "NotificationChannelResponse", spec)
    end

    test "returns 404 for unknown channel", %{conn: conn} do
      conn =
        json_put(
          conn,
          ~p"/api/v1/notification_channels/00000000-0000-0000-0000-000000000000",
          %{name: "X"}
        )

      assert json_response(conn, 404)
    end
  end

  describe "DELETE /api/v1/notification_channels/:id" do
    test "deletes the channel and returns 204", %{conn: conn, workspace: workspace} do
      channel = channel_fixture(workspace.id)

      conn = delete(conn, ~p"/api/v1/notification_channels/#{channel.id}")

      assert response(conn, 204)
      assert {:error, :not_found} = Delivery.get_channel(channel.id)
    end

    test "returns 404 for unknown channel", %{conn: conn} do
      conn =
        delete(conn, ~p"/api/v1/notification_channels/00000000-0000-0000-0000-000000000000")

      assert json_response(conn, 404)
    end
  end

  describe "POST /api/v1/notification_channels/:id/pings" do
    test "enqueues a ping and returns 202", %{conn: conn, workspace: workspace} do
      channel = channel_fixture(workspace.id)

      conn = post(conn, ~p"/api/v1/notification_channels/#{channel.id}/pings")

      assert response(conn, 202)
      assert_enqueued(worker: Holter.Delivery.Workers.WebhookDispatcher, args: %{"test" => true})
    end

    test "returns 404 for unknown channel", %{conn: conn} do
      conn =
        post(
          conn,
          ~p"/api/v1/notification_channels/00000000-0000-0000-0000-000000000000/pings"
        )

      assert json_response(conn, 404)
    end
  end
end
