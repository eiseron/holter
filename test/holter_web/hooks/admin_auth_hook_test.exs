defmodule HolterWeb.Hooks.AdminAuthHookTest do
  use HolterWeb.ConnCase, async: true

  @moduletag :guest

  alias Holter.Repo
  alias Holter.System.Models.Admin
  alias HolterWeb.Hooks.AdminAuthHook

  defp build_socket(session) do
    %Phoenix.LiveView.Socket{
      endpoint: HolterWeb.Endpoint,
      router: HolterWeb.Router,
      assigns: %{__changed__: %{}, flash: %{}}
    }
    |> then(fn s -> {s, session} end)
  end

  defp call_hook(session) do
    {socket, session} = build_socket(session)
    AdminAuthHook.on_mount(:require_admin, %{}, session, socket)
  end

  defp session_for(user) do
    plaintext = session_token_fixture(user)
    %{"user_token" => plaintext}
  end

  describe ":require_admin" do
    test "halts with a redirect when there is no session token" do
      assert {:halt, _socket} = call_hook(%{})
    end

    test "redirects unauthenticated callers to /identity/login" do
      {:halt, halted_socket} = call_hook(%{})

      assert redirected_path(halted_socket) == "/identity/login"
    end

    test "halts when the signed-in user is not an admin" do
      user = user_fixture()
      assert {:halt, _socket} = call_hook(session_for(user))
    end

    test "redirects non-admin signed-in users to /" do
      user = user_fixture()
      {:halt, halted_socket} = call_hook(session_for(user))

      assert redirected_path(halted_socket) == "/"
    end

    test "does not leak an :error flash on the admin-denied redirect" do
      user = user_fixture()
      {:halt, halted_socket} = call_hook(session_for(user))

      refute Map.has_key?(halted_socket.assigns.flash || %{}, "error")
    end

    test "continues when the signed-in user is an active admin" do
      admin = admin_fixture()
      assert {:cont, _socket} = call_hook(session_for(admin.user))
    end

    test "exposes @current_user on a successful mount" do
      admin = admin_fixture()
      {:cont, socket} = call_hook(session_for(admin.user))

      assert socket.assigns.current_user.id == admin.user_id
    end

    test "halts when the user is a revoked admin" do
      anchor = admin_fixture()
      revoked_user = user_fixture()
      revoked = admin_fixture(%{user: revoked_user})

      revoked
      |> Admin.revocation_changeset(%{
        revoked_at: DateTime.utc_now() |> DateTime.truncate(:second),
        revoked_by_admin_id: anchor.id
      })
      |> Repo.update!()

      assert {:halt, _socket} = call_hook(session_for(revoked_user))
    end
  end

  defp redirected_path(socket) do
    case socket.redirected do
      {:redirect, %{to: path}} -> path
      _ -> nil
    end
  end
end
