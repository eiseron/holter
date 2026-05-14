defmodule HolterWeb.Web.Admin.FeatureFlagsLiveTest do
  use HolterWeb.ConnCase, async: false

  @moduletag :guest

  import Phoenix.LiveViewTest

  alias Holter.System.Models.Admin
  alias HolterWeb.Web.Admin.FeatureFlagsLive

  setup do
    on_exit(fn ->
      {:ok, flags} = FunWithFlags.all_flags()
      Enum.each(flags, fn f -> FunWithFlags.clear(f.name) end)
    end)
  end

  describe "auth gate" do
    test "guest is redirected to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/identity/login"}}} =
               live(conn, ~p"/admin/feature-flags")
    end

    test "signed-in non-admin is redirected to /", %{conn: conn} do
      %{user: viewer} = verified_user_fixture()
      conn = log_in_user(conn, viewer)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/feature-flags")
    end
  end

  describe "as admin" do
    setup %{conn: conn} do
      %{user: admin_user} = verified_user_fixture()
      _admin = admin_fixture(%{user: admin_user})
      %{conn: log_in_user(conn, admin_user), admin_user: admin_user}
    end

    test "renders the feature flags heading", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/feature-flags")
      assert html =~ "Feature flags"
    end

    test "lists all known flags", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/feature-flags")
      assert html =~ "maintenance_mode"
    end

    test "shows strategy label for a known flag", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/feature-flags")
      assert html =~ "Global"
    end

    test "strategy_label returns empty string for unknown strategy" do
      assert FeatureFlagsLive.strategy_label(:unknown) == ""
    end

    test "shows percentage strategy label when flag has percentage gate", %{conn: conn} do
      FunWithFlags.enable(:maintenance_mode, for_percentage_of: {:actors, 0.5})
      {:ok, _view, html} = live(conn, ~p"/admin/feature-flags")
      assert html =~ "Percentage"
    end

    test "shows list strategy label when flag has actor gates", %{
      conn: conn,
      admin_user: admin_user
    } do
      FunWithFlags.enable(:maintenance_mode, for_actor: admin_user)
      {:ok, _view, html} = live(conn, ~p"/admin/feature-flags")
      assert html =~ "1 overrides"
    end

    test "toggling a flag updates the UI", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/feature-flags")

      html = view |> element("button[phx-value-name='maintenance_mode']") |> render_click()
      assert html =~ "Flag maintenance_mode toggled."
    end

    test "shows error flash when revoked admin tries to toggle", %{
      conn: conn,
      admin_user: admin_user
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/feature-flags")

      admin = Holter.System.get_admin_by_user_id(admin_user.id)
      anchor = admin_fixture()

      admin
      |> Admin.revocation_changeset(%{
        revoked_at: DateTime.utc_now() |> DateTime.truncate(:second),
        revoked_by_admin_id: anchor.id
      })
      |> Holter.Repo.update!()

      html = view |> element("button[phx-value-name='maintenance_mode']") |> render_click()
      assert html =~ "Could not toggle flag"
    end
  end
end
