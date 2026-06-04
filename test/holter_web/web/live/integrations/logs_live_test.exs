defmodule HolterWeb.Web.Integrations.LogsLiveTest do
  use HolterWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Holter.Repo.Tenant

  setup %{current_user: user} do
    Application.put_env(:holter, :integration_providers, %{
      google_ads: Holter.Integrations.Google.Ads,
      meta_ads: Holter.Integrations.Meta.Ads
    })

    on_exit(fn -> Application.put_env(:holter, :integration_providers, %{}) end)

    workspace = workspace_fixture_for(user)

    integration =
      Tenant.with_user!(user, fn ->
        integration_fixture(%{
          workspace_id: workspace.id,
          provider: :google_ads,
          status: :active
        })
      end)

    %{workspace: workspace, integration: integration}
  end

  describe "mount" do
    test "renders empty state when there are no events",
         %{conn: conn, integration: integration} do
      {:ok, _lv, html} = live(conn, ~p"/integrations/#{integration.id}/logs")

      assert html =~ "No logs yet"
    end

    test "logs tab is the current page",
         %{conn: conn, integration: integration} do
      {:ok, lv, _html} = live(conn, ~p"/integrations/#{integration.id}/logs")

      assert has_element?(lv, "[data-role='tab-logs'][aria-current='page']")
    end

    test "renders activity events when they exist",
         %{conn: conn, integration: integration, current_user: user} do
      Tenant.with_user!(user, fn ->
        integration_event_fixture(
          integration: integration,
          action: "incident_opened",
          status: :success,
          occurred_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )
      end)

      {:ok, lv, _html} = live(conn, ~p"/integrations/#{integration.id}/logs")

      assert has_element?(lv, "[data-role='event-action']", "Incident opened")
    end

    test "renders a failure badge for failed events",
         %{conn: conn, integration: integration, current_user: user} do
      Tenant.with_user!(user, fn ->
        integration_event_fixture(
          integration: integration,
          action: "pause_campaign",
          status: :failed,
          occurred_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )
      end)

      {:ok, lv, _html} = live(conn, ~p"/integrations/#{integration.id}/logs")

      assert has_element?(lv, "[data-role='event-status']", "Failed")
    end
  end

  describe "pagination" do
    test "parse_page falls back to 1 for non-integer ?page=",
         %{conn: conn, integration: integration} do
      {:ok, lv, _html} = live(conn, ~p"/integrations/#{integration.id}/logs?page=abc")

      assert has_element?(lv, "[data-role='tab-logs'][aria-current='page']")
    end

    test "parse_page handles a valid integer string",
         %{conn: conn, integration: integration} do
      {:ok, lv, _html} = live(conn, ~p"/integrations/#{integration.id}/logs?page=1")

      assert has_element?(lv, "[data-role='tab-logs'][aria-current='page']")
    end
  end

  describe "access control" do
    test "redirects unauthenticated users",
         %{integration: integration} do
      conn = build_conn()

      assert {:error, {:redirect, %{to: "/identity/login"}}} =
               live(conn, ~p"/integrations/#{integration.id}/logs")
    end
  end
end
