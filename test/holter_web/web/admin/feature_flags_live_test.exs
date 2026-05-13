defmodule HolterWeb.Web.Admin.FeatureFlagsLiveTest do
  use HolterWeb.ConnCase, async: false

  @moduletag :guest

  import Phoenix.LiveViewTest

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

    test "renders empty state when no flags exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/feature-flags")
      assert html =~ "No feature flags yet"
    end

    test "lists existing flags", %{conn: conn} do
      feature_flag_fixture(%{name: "test_flag_alpha"})
      {:ok, _view, html} = live(conn, ~p"/admin/feature-flags")
      assert html =~ "test_flag_alpha"
    end

    test "shows strategy label for a global flag", %{conn: conn} do
      feature_flag_fixture(%{name: "global_flag"})
      {:ok, _view, html} = live(conn, ~p"/admin/feature-flags")
      assert html =~ "Global"
    end

    test "shows percentage value for a percentage flag", %{conn: conn} do
      feature_flag_fixture(%{name: "pct_flag", strategy: "percentage", percentage: 42})
      {:ok, _view, html} = live(conn, ~p"/admin/feature-flags")
      assert html =~ "42%"
    end

    test "toggling a flag updates the UI", %{conn: conn} do
      feature_flag_fixture(%{name: "toggle_me", enabled: false})
      {:ok, view, _html} = live(conn, ~p"/admin/feature-flags")

      html = view |> element("button[phx-value-name='toggle_me']") |> render_click()
      assert html =~ "Flag toggle_me toggled."
    end

    test "creating a flag adds it to the list", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/feature-flags")

      html =
        view
        |> form("form", flag: %{name: "brand_new_flag"})
        |> render_submit()

      assert html =~ "Flag brand_new_flag created."
      assert html =~ "brand_new_flag"
    end

    test "creating a flag with invalid name shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/feature-flags")

      html =
        view
        |> form("form", flag: %{name: "UPPER-CASE!"})
        |> render_submit()

      assert html =~ "Invalid flag name"
    end
  end
end
