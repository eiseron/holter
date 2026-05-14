defmodule HolterWeb.Web.Admin.ImpersonationControllerTest do
  use HolterWeb.ConnCase, async: true

  @moduletag :guest

  describe "POST create (start impersonation)" do
    test "guest is redirected to login", %{conn: conn} do
      conn = post(conn, ~p"/admin/users/#{Ecto.UUID.generate()}/impersonation")
      assert redirected_to(conn) == "/identity/login"
    end

    test "non-admin is redirected to /", %{conn: conn} do
      %{user: user} = verified_user_fixture()
      target = user_fixture()
      conn = log_in_user(conn, user)
      conn = post(conn, ~p"/admin/users/#{target.id}/impersonation")
      assert redirected_to(conn) == "/"
    end

    test "admin can start impersonating another user", %{conn: conn} do
      %{user: admin_user} = verified_user_fixture()
      _admin = admin_fixture(%{user: admin_user})
      target = user_fixture()

      conn =
        conn
        |> log_in_user(admin_user)
        |> post(~p"/admin/users/#{target.id}/impersonation")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ target.email
      assert get_session(conn, :impersonator_token)
    end

    test "admin cannot impersonate themselves", %{conn: conn} do
      %{user: admin_user} = verified_user_fixture()
      _admin = admin_fixture(%{user: admin_user})

      conn =
        conn
        |> log_in_user(admin_user)
        |> post(~p"/admin/users/#{admin_user.id}/impersonation")

      assert redirected_to(conn) =~ "/admin/users/#{admin_user.id}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "impersonate yourself"
    end

    test "session swaps to target user's token", %{conn: conn} do
      %{user: admin_user} = verified_user_fixture()
      _admin = admin_fixture(%{user: admin_user})
      target = user_fixture()

      conn =
        conn
        |> log_in_user(admin_user)
        |> post(~p"/admin/users/#{target.id}/impersonation")

      new_token = get_session(conn, :user_token)
      resolved = Holter.Identity.fetch_user_by_session_token(new_token)
      assert resolved.id == target.id
    end

    test "preserves admin token as impersonator_token", %{conn: conn} do
      %{user: admin_user} = verified_user_fixture()
      _admin = admin_fixture(%{user: admin_user})
      target = user_fixture()
      conn = log_in_user(conn, admin_user)
      original_token = get_session(conn, :user_token)

      conn = post(conn, ~p"/admin/users/#{target.id}/impersonation")

      assert get_session(conn, :impersonator_token) == original_token
    end
  end

  describe "DELETE delete (stop impersonation)" do
    test "redirects to login when no active session", %{conn: conn} do
      conn = delete(conn, ~p"/admin/impersonation")
      assert redirected_to(conn) == "/identity/login"
    end

    test "flashes error when not impersonating", %{conn: conn} do
      %{user: admin_user} = verified_user_fixture()
      _admin = admin_fixture(%{user: admin_user})

      conn =
        conn
        |> log_in_user(admin_user)
        |> delete(~p"/admin/impersonation")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Not impersonating"
    end

    test "restores admin session when stopping impersonation", %{conn: conn} do
      %{user: admin_user} = verified_user_fixture()
      _admin = admin_fixture(%{user: admin_user})
      target = user_fixture()

      conn =
        conn
        |> log_in_user(admin_user)
        |> post(~p"/admin/users/#{target.id}/impersonation")
        |> carry_session()
        |> delete(~p"/admin/impersonation")

      assert redirected_to(conn) =~ "/admin/users/#{target.id}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Admin session restored"
      refute get_session(conn, :impersonator_token)
    end

    test "admin session token works after restoring", %{conn: conn} do
      %{user: admin_user} = verified_user_fixture()
      _admin = admin_fixture(%{user: admin_user})
      target = user_fixture()

      conn =
        conn
        |> log_in_user(admin_user)
        |> post(~p"/admin/users/#{target.id}/impersonation")
        |> carry_session()
        |> delete(~p"/admin/impersonation")

      restored_token = get_session(conn, :user_token)
      resolved = Holter.Identity.fetch_user_by_session_token(restored_token)
      assert resolved.id == admin_user.id
    end

    test "target session token is revoked after stopping", %{conn: conn} do
      %{user: admin_user} = verified_user_fixture()
      _admin = admin_fixture(%{user: admin_user})
      target = user_fixture()

      conn = log_in_user(conn, admin_user)
      conn = post(conn, ~p"/admin/users/#{target.id}/impersonation")
      target_token = get_session(conn, :user_token)

      conn
      |> recycle()
      |> delete(~p"/admin/impersonation")

      refute Holter.Identity.fetch_user_by_session_token(target_token)
    end
  end

  defp carry_session(conn) do
    session = Plug.Conn.get_session(conn)

    Phoenix.ConnTest.build_conn()
    |> Plug.Test.init_test_session(session)
  end
end
