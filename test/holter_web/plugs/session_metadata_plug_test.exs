defmodule HolterWeb.Plugs.SessionMetadataPlugTest do
  use HolterWeb.ConnCase, async: true

  alias HolterWeb.Plugs.SessionMetadataPlug

  describe "init/1" do
    test "returns opts unchanged" do
      assert SessionMetadataPlug.init(foo: :bar) == [foo: :bar]
    end
  end

  describe "call/2" do
    test "returns a Plug.Conn" do
      conn = build_conn(:get, "/")
      result = SessionMetadataPlug.call(conn, [])
      assert %Plug.Conn{} = result
    end

    test "assigns request_id from existing assigns" do
      conn =
        build_conn(:get, "/")
        |> assign(:request_id, "req-abc-123")

      SessionMetadataPlug.call(conn, [])
      assert Logger.metadata()[:request_id] == "req-abc-123"
    end

    test "sets session_id in Logger metadata from x-session-id header" do
      conn =
        build_conn(:get, "/")
        |> put_req_header("x-session-id", "session-xyz")

      SessionMetadataPlug.call(conn, [])
      assert Logger.metadata()[:session_id] == "session-xyz"
    end

    test "sets request_path in Logger metadata" do
      conn = build_conn(:get, "/some/path")
      SessionMetadataPlug.call(conn, [])
      assert Logger.metadata()[:request_path] == "/some/path"
    end

    test "sets request_method in Logger metadata" do
      conn = build_conn(:post, "/")
      SessionMetadataPlug.call(conn, [])
      assert Logger.metadata()[:request_method] == "POST"
    end

    test "sets remote_ip in Logger metadata as a string" do
      conn = build_conn(:get, "/")
      SessionMetadataPlug.call(conn, [])
      assert is_binary(Logger.metadata()[:remote_ip])
    end

    test "extracts workspace_id from workspace_id query param" do
      conn = build_conn(:get, "/?workspace_id=ws-123")
      conn = Plug.Conn.fetch_query_params(conn)
      SessionMetadataPlug.call(conn, [])
      assert Logger.metadata()[:workspace_id] == "ws-123"
    end

    test "extracts workspace_id from workspace_slug query param" do
      conn = build_conn(:get, "/?workspace_slug=my-org")
      conn = Plug.Conn.fetch_query_params(conn)
      SessionMetadataPlug.call(conn, [])
      assert Logger.metadata()[:workspace_id] == "my-org"
    end

    test "prefers workspace_slug over workspace_id when both present" do
      conn = build_conn(:get, "/?workspace_slug=slug-val&workspace_id=id-val")
      conn = Plug.Conn.fetch_query_params(conn)
      SessionMetadataPlug.call(conn, [])
      assert Logger.metadata()[:workspace_id] == "slug-val"
    end
  end
end
