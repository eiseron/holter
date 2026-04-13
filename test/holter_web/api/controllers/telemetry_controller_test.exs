defmodule HolterWeb.Api.TelemetryControllerTest do
  use HolterWeb.ConnCase

  describe "POST /api/v1/telemetry/logs" do
    test "successfully receives and logs client-side info", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/telemetry/logs", %{
          "level" => "info",
          "message" => "Client loaded",
          "url" => "http://localhost:4000/dashboard"
        })

      assert response(conn, 204) == ""
    end

    test "successfully receives and logs client-side errors with stack", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/telemetry/logs", %{
          "level" => "error",
          "message" => "Uncaught TypeError",
          "stack" => "at dashboard.js:10:5",
          "url" => "http://localhost:4000/dashboard"
        })

      assert response(conn, 204) == ""
    end

    test "rejects logs from untrusted origins", %{conn: conn} do
      conn =
        conn
        |> put_req_header("origin", "https://evil-site.com")
        |> post(~p"/api/v1/telemetry/logs", %{
          "level" => "error",
          "message" => "Attack"
        })

      assert response(conn, 403) == ""
    end
  end
end
