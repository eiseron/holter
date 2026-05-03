defmodule HolterWeb.Api.EmailChannelControllerTest do
  use HolterWeb.ConnCase
  use Oban.Testing, repo: Holter.Repo

  import OpenApiSpex.TestAssertions
  import Swoosh.TestAssertions

  alias Holter.Delivery.EmailChannels
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
      EmailChannels.create(
        Map.merge(
          %{
            workspace_id: workspace_id,
            name: "Ops Email",
            address: "ops-#{System.unique_integer([:positive])}@example.com"
          },
          attrs
        )
      )

    channel
  end

  defp verified_channel_fixture(workspace_id, attrs \\ %{}) do
    channel = channel_fixture(workspace_id, attrs)

    {:ok, _} = EmailChannels.send_verification(channel)
    reloaded = EmailChannels.get!(channel.id)
    {:ok, verified} = EmailChannels.verify(reloaded.verification_token)
    verified
  end

  describe "GET /api/v1/workspaces/:workspace_slug/email_channels" do
    test "returns list of email channels for workspace", %{
      conn: conn,
      workspace: workspace,
      api_spec: spec
    } do
      channel_fixture(workspace.id)

      conn = get(conn, ~p"/api/v1/workspaces/#{workspace.slug}/email_channels")
      body = json_response(conn, 200)

      assert %{"data" => [_]} = body
      assert_schema(body, "EmailChannelList", spec)
    end

    test "returns empty list when workspace has no email channels", %{
      conn: conn,
      workspace: workspace
    } do
      conn = get(conn, ~p"/api/v1/workspaces/#{workspace.slug}/email_channels")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns 404 for unknown workspace slug", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/workspaces/does-not-exist/email_channels")
      assert json_response(conn, 404)
    end
  end

  describe "POST /api/v1/workspaces/:workspace_slug/email_channels" do
    @valid_attrs %{name: "Ops", address: "ops@example.com"}

    test "creates a channel and returns 201", %{conn: conn, workspace: workspace, api_spec: spec} do
      conn =
        json_post(conn, ~p"/api/v1/workspaces/#{workspace.slug}/email_channels", @valid_attrs)

      body = json_response(conn, 201)

      assert body["data"]["name"] == "Ops"
      assert_schema(body, "EmailChannelResponse", spec)
    end

    test "ships a verification email on create", %{conn: conn, workspace: workspace} do
      json_post(conn, ~p"/api/v1/workspaces/#{workspace.slug}/email_channels", @valid_attrs)
      assert_email_sent(to: "ops@example.com")
    end

    test "returns the channel in an unverified state", %{conn: conn, workspace: workspace} do
      conn =
        json_post(conn, ~p"/api/v1/workspaces/#{workspace.slug}/email_channels", @valid_attrs)

      body = json_response(conn, 201)
      assert is_nil(body["data"]["verified_at"])
    end

    test "returns 422 when address is missing", %{conn: conn, workspace: workspace} do
      conn =
        json_post(conn, ~p"/api/v1/workspaces/#{workspace.slug}/email_channels", %{
          name: "Bad"
        })

      assert json_response(conn, 422)
    end

    test "returns 422 for an invalid address", %{conn: conn, workspace: workspace} do
      conn =
        json_post(conn, ~p"/api/v1/workspaces/#{workspace.slug}/email_channels", %{
          name: "Bad",
          address: "not-an-email"
        })

      resp = json_response(conn, 422)
      assert resp["error"]["code"] == "validation_failed"
    end
  end

  describe "GET /api/v1/email_channels/:id" do
    test "returns the channel", %{conn: conn, workspace: workspace, api_spec: spec} do
      channel = channel_fixture(workspace.id)
      conn = get(conn, ~p"/api/v1/email_channels/#{channel.id}")
      body = json_response(conn, 200)

      assert body["data"]["id"] == channel.id
      assert_schema(body, "EmailChannelResponse", spec)
    end

    test "returns 404 for unknown id", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/email_channels/00000000-0000-0000-0000-000000000000")
      assert json_response(conn, 404)
    end
  end

  describe "PUT /api/v1/email_channels/:id" do
    test "updates the channel name", %{conn: conn, workspace: workspace, api_spec: spec} do
      channel = channel_fixture(workspace.id)

      conn =
        json_put(conn, ~p"/api/v1/email_channels/#{channel.id}", %{name: "Updated"})

      body = json_response(conn, 200)

      assert body["data"]["name"] == "Updated"
      assert_schema(body, "EmailChannelResponse", spec)
    end

    test "returns 404 for unknown channel", %{conn: conn} do
      conn =
        json_put(conn, ~p"/api/v1/email_channels/00000000-0000-0000-0000-000000000000", %{
          name: "X"
        })

      assert json_response(conn, 404)
    end
  end

  describe "DELETE /api/v1/email_channels/:id" do
    test "deletes the channel and returns 204", %{conn: conn, workspace: workspace} do
      channel = channel_fixture(workspace.id)
      conn = delete(conn, ~p"/api/v1/email_channels/#{channel.id}")
      assert conn.status == 204
    end

    test "returns 404 for unknown channel", %{conn: conn} do
      conn = delete(conn, ~p"/api/v1/email_channels/00000000-0000-0000-0000-000000000000")
      assert json_response(conn, 404)
    end
  end

  describe "POST /api/v1/email_channels/:id/pings" do
    test "enqueues a test dispatch when the address is verified", %{
      conn: conn,
      workspace: workspace
    } do
      channel = verified_channel_fixture(workspace.id)
      conn = post(conn, ~p"/api/v1/email_channels/#{channel.id}/pings")

      assert conn.status == 202
      assert_enqueued(worker: Holter.Delivery.Workers.EmailDispatcher)
    end

    test "returns 422 when the channel has no verified address", %{
      conn: conn,
      workspace: workspace
    } do
      channel = channel_fixture(workspace.id)
      conn = post(conn, ~p"/api/v1/email_channels/#{channel.id}/pings")

      resp = json_response(conn, 422)
      assert resp["error"]["code"] == "no_verified_recipients"
    end

    test "returns 404 for unknown channel", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/email_channels/00000000-0000-0000-0000-000000000000/pings")

      assert json_response(conn, 404)
    end
  end

  describe "PUT /api/v1/email_channels/:id/anti_phishing_code" do
    test "rotates the anti-phishing code", %{conn: conn, workspace: workspace, api_spec: spec} do
      channel = channel_fixture(workspace.id)
      original_code = channel.anti_phishing_code

      conn = put(conn, ~p"/api/v1/email_channels/#{channel.id}/anti_phishing_code")
      body = json_response(conn, 200)

      assert body["data"]["anti_phishing_code"] != original_code
      assert_schema(body, "EmailChannelResponse", spec)
    end

    test "returns 404 for unknown channel", %{conn: conn} do
      conn =
        put(
          conn,
          ~p"/api/v1/email_channels/00000000-0000-0000-0000-000000000000/anti_phishing_code"
        )

      assert json_response(conn, 404)
    end
  end
end
