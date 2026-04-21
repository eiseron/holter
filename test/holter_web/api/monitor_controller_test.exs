defmodule HolterWeb.Api.MonitorControllerTest do
  use HolterWeb.ConnCase
  use Oban.Testing, repo: Holter.Repo

  import OpenApiSpex.TestAssertions

  alias Holter.Monitoring
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

  defp json_post(conn, path, body) do
    post(conn, path, Jason.encode!(body))
  end

  defp json_put(conn, path, body) do
    put(conn, path, Jason.encode!(body))
  end

  describe "GET /api/v1/workspaces/:workspace_slug/monitors" do
    test "Lists monitors for the workspace", %{conn: conn, workspace: workspace, api_spec: spec} do
      monitor_fixture(%{workspace_id: workspace.id})

      conn = get(conn, ~p"/api/v1/workspaces/#{workspace.slug}/monitors")
      body = json_response(conn, 200)

      assert %{"data" => [_]} = body
      assert_schema(body, "MonitorList", spec)
    end

    test "Filters monitors by health_status", %{conn: conn, workspace: workspace} do
      monitor_fixture(%{workspace_id: workspace.id, health_status: :down})
      monitor_fixture(%{workspace_id: workspace.id, health_status: :up})

      conn = get(conn, ~p"/api/v1/workspaces/#{workspace.slug}/monitors?health_status=down")

      assert %{"data" => [m]} = json_response(conn, 200)
      assert m["health_status"] == "down"
    end

    test "Returns empty list if workspace has no monitors", %{conn: conn, workspace: workspace} do
      conn = get(conn, ~p"/api/v1/workspaces/#{workspace.slug}/monitors")
      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  describe "POST /api/v1/workspaces/:workspace_slug/monitors" do
    @valid_attrs %{url: "https://api-test.local", method: "get", interval_seconds: 60}

    test "Creates a monitor and triggers initial check", %{
      conn: conn,
      workspace: workspace,
      api_spec: spec
    } do
      conn = json_post(conn, ~p"/api/v1/workspaces/#{workspace.slug}/monitors", @valid_attrs)
      body = json_response(conn, 201)

      assert %{"id" => id} = body["data"]
      assert Monitoring.get_monitor!(id).workspace_id == workspace.id
      assert_enqueued(worker: Holter.Monitoring.Workers.HTTPCheck, args: %{"id" => id})
      assert_schema(body, "MonitorResponse", spec)
    end

    test "Returns 422 for invalid data", %{conn: conn, workspace: workspace} do
      conn = json_post(conn, ~p"/api/v1/workspaces/#{workspace.slug}/monitors", %{url: nil})
      resp = json_response(conn, 422)
      assert resp["error"]["code"] == "validation_failed"
    end
  end

  describe "GET /api/v1/monitors/:id" do
    test "Returns monitor details", %{conn: conn, workspace: workspace, api_spec: spec} do
      monitor = monitor_fixture(%{workspace_id: workspace.id})
      conn = get(conn, ~p"/api/v1/monitors/#{monitor.id}")
      body = json_response(conn, 200)

      assert body["data"]["id"] == monitor.id
      assert_schema(body, "MonitorResponse", spec)
    end
  end

  describe "PUT /api/v1/monitors/:id" do
    test "Updates monitor and returns 200", %{conn: conn, workspace: workspace, api_spec: spec} do
      monitor = monitor_fixture(%{workspace_id: workspace.id})

      conn =
        json_put(conn, ~p"/api/v1/monitors/#{monitor.id}", %{
          "monitor" => %{"url" => "https://updated.local"}
        })

      body = json_response(conn, 200)
      assert body["data"]["url"] == "https://updated.local"
      assert_schema(body, "MonitorResponse", spec)
    end
  end

  describe "POST /api/v1/workspaces/:workspace_slug/monitors — quota enforcement" do
    test "returns 422 when workspace is at max_monitors capacity", %{conn: conn} do
      full_workspace = workspace_fixture(%{max_monitors: 1})
      monitor_fixture(%{workspace_id: full_workspace.id})

      conn =
        json_post(conn, ~p"/api/v1/workspaces/#{full_workspace.slug}/monitors", %{
          url: "https://example.com",
          method: "get",
          interval_seconds: 60
        })

      assert %{
               "error" => %{
                 "code" => "quota_reached",
                 "message" => "Monitor limit reached for this workspace"
               }
             } =
               json_response(conn, 422)
    end

    test "returns 422 when interval_seconds is below workspace minimum", %{conn: conn} do
      strict_workspace = workspace_fixture(%{min_interval_seconds: 300})

      conn =
        json_post(conn, ~p"/api/v1/workspaces/#{strict_workspace.slug}/monitors", %{
          url: "https://example.com",
          method: "get",
          interval_seconds: 60
        })

      assert %{"error" => _} = json_response(conn, 422)
    end

    test "returns 422 when timeout >= interval_seconds", %{conn: conn, workspace: workspace} do
      conn =
        json_post(conn, ~p"/api/v1/workspaces/#{workspace.slug}/monitors", %{
          url: "https://example.com",
          method: "get",
          interval_seconds: 60,
          timeout_seconds: 60
        })

      assert %{"error" => _} = json_response(conn, 422)
    end

    test "returns 422 when body is sent with GET method", %{conn: conn, workspace: workspace} do
      conn =
        json_post(conn, ~p"/api/v1/workspaces/#{workspace.slug}/monitors", %{
          url: "https://example.com",
          method: "get",
          interval_seconds: 60,
          body: "{\"key\": \"value\"}"
        })

      assert %{"error" => _} = json_response(conn, 422)
    end

    test "returns 422 when body is invalid JSON", %{conn: conn, workspace: workspace} do
      conn =
        json_post(conn, ~p"/api/v1/workspaces/#{workspace.slug}/monitors", %{
          url: "https://example.com",
          method: "post",
          interval_seconds: 60,
          body: "not json"
        })

      assert %{"error" => _} = json_response(conn, 422)
    end
  end

  describe "PUT /api/v1/monitors/:id — quota enforcement" do
    test "returns 422 when interval_seconds is below workspace minimum", %{conn: conn} do
      strict_workspace = workspace_fixture(%{min_interval_seconds: 300})
      monitor = monitor_fixture(%{workspace_id: strict_workspace.id, interval_seconds: 300})

      conn =
        json_put(conn, ~p"/api/v1/monitors/#{monitor.id}", %{
          "monitor" => %{"interval_seconds" => 60}
        })

      assert %{"error" => _} = json_response(conn, 422)
    end

    test "returns 422 when timeout >= interval_seconds", %{conn: conn, workspace: workspace} do
      monitor = monitor_fixture(%{workspace_id: workspace.id, interval_seconds: 120})

      conn =
        json_put(conn, ~p"/api/v1/monitors/#{monitor.id}", %{
          "monitor" => %{"timeout_seconds" => 120}
        })

      assert %{"error" => _} = json_response(conn, 422)
    end
  end

  describe "PUT /api/v1/monitors/:id — security & quota bypass" do
    test "prevents bypassing quota by changing workspace_id", %{conn: conn, workspace: workspace} do
      other_workspace = workspace_fixture()
      monitor = monitor_fixture(%{workspace_id: workspace.id})

      json_put(conn, ~p"/api/v1/monitors/#{monitor.id}", %{
        "monitor" => %{"workspace_id" => other_workspace.id}
      })

      updated_monitor = Monitoring.get_monitor!(monitor.id)
      assert updated_monitor.workspace_id == workspace.id
    end

    test "prevents bypassing quota by unarchiving a monitor", %{conn: conn} do
      full_workspace = workspace_fixture(%{max_monitors: 1})
      monitor_fixture(%{workspace_id: full_workspace.id})

      archived_monitor =
        monitor_fixture(%{workspace_id: full_workspace.id, logical_state: :archived})

      assert Monitoring.at_quota?(full_workspace)

      conn =
        json_put(conn, ~p"/api/v1/monitors/#{archived_monitor.id}", %{
          "monitor" => %{"logical_state" => "active"}
        })

      resp = json_response(conn, 422)
      assert resp["error"]["code"] == "validation_failed"

      assert resp["error"]["details"]["logical_state"] == [
               "Monitor limit reached for this workspace"
             ]
    end
  end

  describe "DELETE /api/v1/monitors/:id" do
    test "Deletes monitor and returns 204", %{conn: conn, workspace: workspace} do
      monitor = monitor_fixture(%{workspace_id: workspace.id})

      conn = delete(conn, ~p"/api/v1/monitors/#{monitor.id}")
      assert response(conn, 204)
      assert Monitoring.get_monitor(monitor.id) == {:error, :not_found}
    end
  end
end
