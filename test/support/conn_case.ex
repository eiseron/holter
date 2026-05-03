defmodule HolterWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use HolterWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint HolterWeb.Endpoint

      use HolterWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import HolterWeb.ConnCase
      import Holter.IdentityFixtures
      import Holter.MonitoringFixtures
    end
  end

  setup tags do
    alias Phoenix.Ecto.SQL.Sandbox, as: SqlSandbox

    pid = Holter.DataCase.setup_sandbox(tags)
    Mox.stub_with(Holter.Network.ResolverMock, Holter.Test.StubResolver)
    metadata = SqlSandbox.metadata_for(Holter.Repo, pid)
    encoded = SqlSandbox.encode_metadata(metadata)

    base_conn =
      Phoenix.ConnTest.build_conn()
      |> Plug.Conn.put_req_header("user-agent", encoded)

    if tags[:guest] do
      {:ok, conn: base_conn}
    else
      %{user: user, workspace: workspace} = Holter.IdentityFixtures.verified_user_fixture()
      flush_test_mailbox()
      Process.put(:current_test_user, user)
      conn = log_in_user(base_conn, user)
      {:ok, conn: conn, current_user: user, current_workspace: workspace}
    end
  end

  @doc """
  Stamps a session token for `user` on `conn` so subsequent LiveView
  mounts find a current user via `HolterWeb.Hooks.UserAuthHook` and
  bypass the `:require_authenticated` gate.
  """
  def log_in_user(conn, user) do
    token = Holter.IdentityFixtures.session_token_fixture(user)

    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  defp flush_test_mailbox do
    receive do
      {:email, _} -> flush_test_mailbox()
    after
      0 -> :ok
    end
  end
end
