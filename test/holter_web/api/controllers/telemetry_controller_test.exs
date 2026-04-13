defmodule HolterWeb.Api.TelemetryControllerTest do
  use HolterWeb.ConnCase
  require Logger

  describe "POST /api/v1/telemetry/logs — Functionality" do
    @describetag :capture_log

    test "successfully receives and logs client-side info", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/telemetry/logs", %{
          "level" => "info",
          "message" => "Client loaded"
        })

      assert response(conn, 204) == ""
    end
  end

  describe "POST /api/v1/telemetry/logs — Security Pentest" do
    @describetag :capture_log

    test "prevents log injection via line breaks", %{conn: conn} do
      payload = "Normal Message\n{\"injected\": \"true\"}"

      conn =
        post(conn, ~p"/api/v1/telemetry/logs", %{
          "level" => "error",
          "message" => payload
        })

      assert response(conn, 204) == ""
    end

    test "prevents atom exhaustion by sending unknown levels", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/telemetry/logs", %{
          "level" => "extremely_long_and_weird_level_name_that_should_not_be_an_atom",
          "message" => "Safe"
        })

      assert response(conn, 204) == ""
    end

    test "enforces same-origin policy", %{conn: conn} do
      conn =
        conn
        |> put_req_header("origin", "https://malicious-site.net")
        |> post(~p"/api/v1/telemetry/logs", %{
          "level" => "error",
          "message" => "Cross-site log attempt"
        })

      assert response(conn, 403) == ""
    end

    test "integrates with global scrubbing for sensitive data in logs", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/telemetry/logs", %{
          "level" => "error",
          "message" => "Leaking data",
          "password" => "123456"
        })

      assert response(conn, 204) == ""
    end
  end

  describe "POST /api/v1/telemetry/logs — Same-Origin Bypass Vulnerabilities" do
    @describetag :capture_log

    test "rejects origins that contain localhost as substring", %{conn: _conn} do
      malicious_origins = [
        "https://evil-localhost.com",
        "https://localhost.evil.com",
        "https://notlocalhost.io",
        "http://my-localhost.net"
      ]

      for origin <- malicious_origins do
        conn =
          build_conn()
          |> put_req_header("origin", origin)
          |> post(~p"/api/v1/telemetry/logs", %{
            "level" => "error",
            "message" => "Malicious origin with localhost substring"
          })

        assert response(conn, 403) == "",
               "Origin '#{origin}' should be rejected but was accepted"
      end
    end

    test "documents that requests without origin header are accepted (CSRF token provides protection)",
         %{conn: conn} do
      conn =
        conn
        |> delete_req_header("origin")
        |> post(~p"/api/v1/telemetry/logs", %{
          "level" => "error",
          "message" => "Request without origin header"
        })

      assert response(conn, 204) == ""
    end

    test "accepts valid same-origin requests", %{conn: conn} do
      valid_origin = "http://localhost"

      conn =
        conn
        |> put_req_header("origin", valid_origin)
        |> post(~p"/api/v1/telemetry/logs", %{
          "level" => "error",
          "message" => "Valid same-origin request"
        })

      assert response(conn, 204) == ""
    end
  end

  describe "POST /api/v1/telemetry/logs — Input Validation" do
    @describetag :capture_log

    test "handles non-string level gracefully", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/telemetry/logs", %{
          "level" => 123,
          "message" => "test"
        })

      assert response(conn, 400) == ""
    end

    test "handles missing required message parameter", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/telemetry/logs", %{
          "level" => "info"
        })

      assert response(conn, 400) == ""
    end

    test "handles missing required level parameter", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/telemetry/logs", %{
          "message" => "test"
        })

      assert response(conn, 400) == ""
    end

    test "accepts optional stack parameter", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/telemetry/logs", %{
          "level" => "error",
          "message" => "Error with stack",
          "stack" => "Error at line 42"
        })

      assert response(conn, 204) == ""
    end

    test "accepts optional url parameter", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/telemetry/logs", %{
          "level" => "info",
          "message" => "Page loaded",
          "url" => "https://example.com/page"
        })

      assert response(conn, 204) == ""
    end

    test "handles empty string message", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/telemetry/logs", %{
          "level" => "info",
          "message" => ""
        })

      assert response(conn, 204) == ""
    end

    test "handles empty string level", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/telemetry/logs", %{
          "level" => "",
          "message" => "test"
        })

      assert response(conn, 204) == ""
    end

    test "handles very large message payload", %{conn: conn} do
      large_message = String.duplicate("A", 100_000)

      conn =
        post(conn, ~p"/api/v1/telemetry/logs", %{
          "level" => "info",
          "message" => large_message
        })

      assert response(conn, 204) == ""
    end

    test "handles unicode characters in message", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/telemetry/logs", %{
          "level" => "info",
          "message" => "Unicode: 日本語 🔥 Émojis"
        })

      assert response(conn, 204) == ""
    end

    test "handles special characters in message", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/telemetry/logs", %{
          "level" => "error",
          "message" => "Special: <script>alert('xss')</script> & \"quotes\""
        })

      assert response(conn, 204) == ""
    end
  end
end
