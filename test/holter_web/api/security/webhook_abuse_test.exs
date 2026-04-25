defmodule HolterWeb.Api.Security.WebhookAbuseTest do
  use HolterWeb.ConnCase, async: false
  use Oban.Testing, repo: Holter.Repo

  alias Holter.Delivery

  setup %{conn: conn} do
    workspace = workspace_fixture()

    {:ok, channel} =
      Delivery.create_channel(%{
        workspace_id: workspace.id,
        name: "Test Hook",
        type: :webhook,
        target: "https://example.com/hook"
      })

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")

    {:ok, conn: conn, workspace: workspace, channel: channel}
  end

  describe "SSRF prevention — channel create via API" do
    test "creating a webhook channel with http://localhost target returns 422",
         %{conn: conn, workspace: workspace} do
      conn =
        post(
          conn,
          ~p"/api/v1/workspaces/#{workspace.slug}/notification_channels",
          Jason.encode!(%{name: "Bad", type: "webhook", target: "http://localhost/hook"})
        )

      resp = json_response(conn, 422)
      assert resp["error"]["code"] == "validation_failed"
    end

    test "creating a webhook channel with http://127.0.0.1 target returns 422",
         %{conn: conn, workspace: workspace} do
      conn =
        post(
          conn,
          ~p"/api/v1/workspaces/#{workspace.slug}/notification_channels",
          Jason.encode!(%{name: "Bad", type: "webhook", target: "http://127.0.0.1/hook"})
        )

      assert json_response(conn, 422)
    end

    test "creating a webhook channel with http://169.254.169.254 target returns 422",
         %{conn: conn, workspace: workspace} do
      conn =
        post(
          conn,
          ~p"/api/v1/workspaces/#{workspace.slug}/notification_channels",
          Jason.encode!(%{
            name: "Metadata",
            type: "webhook",
            target: "http://169.254.169.254/latest/meta-data"
          })
        )

      assert json_response(conn, 422)
    end

    test "creating a webhook channel with http://192.168.1.1 target returns 422",
         %{conn: conn, workspace: workspace} do
      conn =
        post(
          conn,
          ~p"/api/v1/workspaces/#{workspace.slug}/notification_channels",
          Jason.encode!(%{name: "Internal", type: "webhook", target: "http://192.168.1.1/hook"})
        )

      assert json_response(conn, 422)
    end

    test "creating a webhook channel with a public URL succeeds",
         %{conn: conn, workspace: workspace} do
      conn =
        post(
          conn,
          ~p"/api/v1/workspaces/#{workspace.slug}/notification_channels",
          Jason.encode!(%{name: "Good", type: "webhook", target: "https://hooks.example.com/ok"})
        )

      assert json_response(conn, 201)
    end
  end

  describe "test dispatch — no rate limiting enforced yet" do
    test "calling test dispatch 5 times in rapid succession all return 202",
         %{conn: conn, channel: channel} do
      results =
        Enum.map(1..5, fn _ ->
          post(conn, ~p"/api/v1/notification_channels/#{channel.id}/pings")
          |> response(:accepted)
        end)

      assert Enum.all?(results, &(&1 == ""))
    end
  end
end
