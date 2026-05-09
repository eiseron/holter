defmodule HolterWeb.ApiTenancyTest do
  use HolterWeb.ConnCase, async: false

  alias Holter.Repo.Tenant

  defmodule TestController do
    use Phoenix.Controller, formats: []
    use HolterWeb.ApiTenancy

    def report(conn, _params) do
      Phoenix.Controller.json(conn, %{
        tenant: Tenant.current_workspace_id() || "none"
      })
    end
  end

  describe "action/2 wrap" do
    test "stamps app.current_workspace_id for the duration of the action" do
      workspace = workspace_fixture()

      conn =
        build_conn(:get, "/")
        |> Plug.Conn.put_private(:phoenix_action, :report)
        |> Plug.Conn.put_private(:phoenix_controller, TestController)
        |> Plug.Conn.assign(:current_workspace, workspace)

      conn = TestController.call(conn, TestController.init(:report))

      assert conn.resp_body == ~s({"tenant":"#{workspace.id}"})
    end

    test "passes through with no tenant when :current_workspace is missing" do
      conn =
        build_conn(:get, "/")
        |> Plug.Conn.put_private(:phoenix_action, :report)
        |> Plug.Conn.put_private(:phoenix_controller, TestController)

      conn = TestController.call(conn, TestController.init(:report))

      assert conn.resp_body == ~s({"tenant":"none"})
    end
  end
end
