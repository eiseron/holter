defmodule HolterWeb.Api.WebhookChannelControllerTest do
  use HolterWeb.ConnCase
  use Oban.Testing, repo: Holter.Repo

  import OpenApiSpex.TestAssertions

  alias Holter.Delivery.WebhookChannels
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
      WebhookChannels.create(
        Map.merge(
          %{
            workspace_id: workspace_id,
            name: "Test Webhook",
            url: "https://example.com/hook"
          },
          attrs
        )
      )

    channel
  end

  describe "GET /api/v1/workspaces/:workspace_slug/webhook_channels" do
    test "returns list of webhook channels for workspace", %{
      conn: conn,
      workspace: workspace,
      api_spec: spec
    } do
      channel_fixture(workspace.id)

      conn = get(conn, ~p"/api/v1/workspaces/#{workspace.slug}/webhook_channels")
      body = json_response(conn, 200)

      assert %{"data" => [_]} = body
      assert_schema(body, "WebhookChannelList", spec)
    end

    test "returns empty list when workspace has no webhook channels", %{
      conn: conn,
      workspace: workspace
    } do
      conn = get(conn, ~p"/api/v1/workspaces/#{workspace.slug}/webhook_channels")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns 404 for unknown workspace slug", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/workspaces/does-not-exist/webhook_channels")
      assert json_response(conn, 404)
    end
  end

  describe "POST /api/v1/workspaces/:workspace_slug/webhook_channels" do
    @valid_attrs %{name: "My Hook", url: "https://hooks.example.com/notify"}

    test "creates a channel and returns 201", %{conn: conn, workspace: workspace, api_spec: spec} do
      conn =
        json_post(conn, ~p"/api/v1/workspaces/#{workspace.slug}/webhook_channels", @valid_attrs)

      body = json_response(conn, 201)

      assert body["data"]["name"] == "My Hook"
      assert_schema(body, "WebhookChannelResponse", spec)
    end

    test "returns 422 when url is missing", %{conn: conn, workspace: workspace} do
      conn =
        json_post(conn, ~p"/api/v1/workspaces/#{workspace.slug}/webhook_channels", %{
          name: "Bad"
        })

      assert json_response(conn, 422)
    end

    test "returns 422 for an invalid URL", %{conn: conn, workspace: workspace} do
      conn =
        json_post(conn, ~p"/api/v1/workspaces/#{workspace.slug}/webhook_channels", %{
          name: "Bad",
          url: "not-a-url"
        })

      resp = json_response(conn, 422)
      assert resp["error"]["code"] == "validation_failed"
    end
  end

  describe "GET /api/v1/webhook_channels/:id" do
    test "returns the channel", %{conn: conn, workspace: workspace, api_spec: spec} do
      channel = channel_fixture(workspace.id)
      conn = get(conn, ~p"/api/v1/webhook_channels/#{channel.id}")
      body = json_response(conn, 200)

      assert body["data"]["id"] == channel.id
      assert_schema(body, "WebhookChannelResponse", spec)
    end

    test "returns 404 for unknown id", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/webhook_channels/00000000-0000-0000-0000-000000000000")
      assert json_response(conn, 404)
    end
  end

  describe "PUT /api/v1/webhook_channels/:id" do
    test "updates the channel name", %{conn: conn, workspace: workspace, api_spec: spec} do
      channel = channel_fixture(workspace.id)

      conn =
        json_put(conn, ~p"/api/v1/webhook_channels/#{channel.id}", %{name: "Updated"})

      body = json_response(conn, 200)

      assert body["data"]["name"] == "Updated"
      assert_schema(body, "WebhookChannelResponse", spec)
    end

    test "returns 404 for unknown channel", %{conn: conn} do
      conn =
        json_put(conn, ~p"/api/v1/webhook_channels/00000000-0000-0000-0000-000000000000", %{
          name: "X"
        })

      assert json_response(conn, 404)
    end
  end

  describe "DELETE /api/v1/webhook_channels/:id" do
    test "deletes the channel and returns 204", %{conn: conn, workspace: workspace} do
      channel = channel_fixture(workspace.id)
      conn = delete(conn, ~p"/api/v1/webhook_channels/#{channel.id}")
      assert conn.status == 204
    end

    test "returns 404 for unknown channel", %{conn: conn} do
      conn = delete(conn, ~p"/api/v1/webhook_channels/00000000-0000-0000-0000-000000000000")
      assert json_response(conn, 404)
    end
  end

  describe "POST /api/v1/webhook_channels/:id/pings" do
    test "enqueues a test dispatch and returns 202", %{conn: conn, workspace: workspace} do
      channel = channel_fixture(workspace.id)
      conn = post(conn, ~p"/api/v1/webhook_channels/#{channel.id}/pings")

      assert conn.status == 202
      assert_enqueued(worker: Holter.Delivery.Workers.WebhookDispatcher)
    end

    test "returns 404 for unknown channel", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/webhook_channels/00000000-0000-0000-0000-000000000000/pings")

      assert json_response(conn, 404)
    end
  end

  describe "PUT /api/v1/webhook_channels/:id/signing_token" do
    test "rotates the signing token", %{conn: conn, workspace: workspace, api_spec: spec} do
      channel = channel_fixture(workspace.id)
      original_token = channel.signing_token

      conn = put(conn, ~p"/api/v1/webhook_channels/#{channel.id}/signing_token")
      body = json_response(conn, 200)

      assert body["data"]["signing_token"] != original_token
      assert_schema(body, "WebhookChannelResponse", spec)
    end

    test "returns 404 for unknown channel", %{conn: conn} do
      conn =
        put(
          conn,
          ~p"/api/v1/webhook_channels/00000000-0000-0000-0000-000000000000/signing_token"
        )

      assert json_response(conn, 404)
    end
  end
end
