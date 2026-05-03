defmodule HolterWeb.Hooks.UserAuthHookTest do
  use HolterWeb.ConnCase, async: true

  @moduletag :guest

  import Phoenix.LiveViewTest

  describe ":require_authenticated" do
    test "redirects unauthenticated mounts to /identity/login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/identity/login"}}} =
               live(conn, ~p"/monitoring/workspaces/dev/monitors")
    end

    test "stamps a sign-in flash on the redirect", %{conn: conn} do
      {:error, {:redirect, %{flash: flash}}} =
        live(conn, ~p"/monitoring/workspaces/dev/monitors")

      assert Phoenix.Flash.get(flash, :error) =~ "sign in"
    end

    test "lets a signed-in user reach the protected mount", %{conn: conn} do
      %{user: user, workspace: workspace} = verified_user_fixture()

      assert {:ok, _lv, _html} =
               conn
               |> log_in_user(user)
               |> live(~p"/monitoring/workspaces/#{workspace.slug}/monitors")
    end
  end

  describe ":require_workspace_member" do
    test "lets a member reach the workspace mount", %{conn: conn} do
      %{user: user, workspace: workspace} = verified_user_fixture()

      assert {:ok, _lv, _html} =
               conn
               |> log_in_user(user)
               |> live(~p"/monitoring/workspaces/#{workspace.slug}/monitors")
    end

    test "redirects to / when the workspace slug does not exist", %{conn: conn} do
      %{user: user} = verified_user_fixture()

      assert {:error, {:redirect, %{to: "/"}}} =
               conn
               |> log_in_user(user)
               |> live(~p"/monitoring/workspaces/nonexistent-slug/monitors")
    end

    test "redirects to / when the signed-in user is not a member of the workspace",
         %{conn: conn} do
      %{user: user_a} = verified_user_fixture()
      other_workspace = workspace_fixture()

      assert {:error, {:redirect, %{to: "/"}}} =
               conn
               |> log_in_user(user_a)
               |> live(~p"/monitoring/workspaces/#{other_workspace.slug}/monitors")
    end

    test "exposes the resolved workspace as @current_workspace", %{conn: conn} do
      %{user: user, workspace: workspace} = verified_user_fixture()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/monitoring/workspaces/#{workspace.slug}/monitors")

      assigns = :sys.get_state(view.pid).socket.assigns

      assert assigns.current_workspace.id == workspace.id
    end
  end

  describe ":redirect_if_authenticated" do
    test "passes through when no user is signed in", %{conn: conn} do
      assert {:ok, _lv, html} = live(conn, ~p"/identity/login")

      assert html =~ "Sign in to Holter"
    end

    test "redirects a signed-in user to the workspace dashboard", %{conn: conn} do
      %{user: user, workspace: workspace} = verified_user_fixture()

      assert {:error, {:redirect, %{to: to}}} =
               conn
               |> log_in_user(user)
               |> live(~p"/identity/login")

      assert to == "/monitoring/workspaces/#{workspace.slug}/monitors"
    end
  end

  describe ":assign_current_user" do
    test "exposes a public token-verify mount without gating", %{conn: conn} do
      %{raw_verify_token: token} = register_user_fixture()

      assert {:error, {:live_redirect, %{to: "/identity/login"}}} =
               live(conn, ~p"/identity/verify-email/#{token}")
    end
  end
end
