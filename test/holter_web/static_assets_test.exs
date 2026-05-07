defmodule HolterWeb.StaticAssetsTest do
  use HolterWeb.ConnCase, async: true

  test "static asset response uses StaticCachePolicy etag value", %{conn: conn} do
    conn = get(conn, "/favicon.ico")

    assert conn.status == 200

    assert get_resp_header(conn, "cache-control") == [
             HolterWeb.StaticCachePolicy.etag_cache_control(false)
           ]
  end
end
