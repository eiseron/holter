defmodule HolterWeb.HealthControllerTest do
  use HolterWeb.ConnCase, async: true

  test "GET /healthz returns 200 with status ok", %{conn: conn} do
    conn = get(conn, ~p"/healthz")
    assert json_response(conn, 200) == %{"status" => "ok"}
  end
end
