defmodule HolterWeb.Web.Integrations.CatalogLiveTest do
  use HolterWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Holter.Repo.Tenant

  defmodule NotifStub do
    @moduledoc false
    @behaviour Holter.Integrations.Provider
    def display_name, do: "NotifStub"
    def category, do: :notifications
    def icon, do: "stub"
    def oauth_url(_w, _s), do: {:ok, ""}
    def handle_callback(_p, _s), do: {:ok, %{}}
    def refresh(_c), do: {:ok, %{}}
    def encode(_action, _target, _integration), do: :unsupported
    def revoke(_c), do: :ok
    def supported_actions, do: []
    def supported_events, do: []
  end

  defmodule IssueStub do
    @moduledoc false
    @behaviour Holter.Integrations.Provider
    def display_name, do: "IssueStub"
    def category, do: :issue_tracking
    def icon, do: "issue"
    def oauth_url(_w, _s), do: {:ok, ""}
    def handle_callback(_p, _s), do: {:ok, %{}}
    def refresh(_c), do: {:ok, %{}}
    def encode(_action, _target, _integration), do: :unsupported
    def revoke(_c), do: :ok
    def supported_actions, do: []
    def supported_events, do: []
  end

  defmodule StatusStub do
    @moduledoc false
    @behaviour Holter.Integrations.Provider
    def display_name, do: "StatusStub"
    def category, do: :status_page
    def icon, do: "status"
    def oauth_url(_w, _s), do: {:ok, ""}
    def handle_callback(_p, _s), do: {:ok, %{}}
    def refresh(_c), do: {:ok, %{}}
    def encode(_action, _target, _integration), do: :unsupported
    def revoke(_c), do: :ok
    def supported_actions, do: []
    def supported_events, do: []
  end

  defmodule CalendarStub do
    @moduledoc false
    @behaviour Holter.Integrations.Provider
    def display_name, do: "CalendarStub"
    def category, do: :calendar
    def icon, do: "calendar"
    def oauth_url(_w, _s), do: {:ok, ""}
    def handle_callback(_p, _s), do: {:ok, %{}}
    def refresh(_c), do: {:ok, %{}}
    def encode(_action, _target, _integration), do: :unsupported
    def revoke(_c), do: :ok
    def supported_actions, do: []
    def supported_events, do: []
  end

  setup %{current_user: user} do
    Application.put_env(:holter, :integration_providers, %{
      google_ads: Holter.Integrations.Google.Ads,
      meta_ads: Holter.Integrations.Meta.Ads,
      slack: NotifStub,
      linear: IssueStub,
      statuspage: StatusStub,
      google_calendar: CalendarStub
    })

    on_exit(fn -> Application.put_env(:holter, :integration_providers, %{}) end)

    workspace = workspace_fixture_for(user)
    %{workspace: workspace}
  end

  describe "mount" do
    test "Given a valid workspace slug, when mounted, then the catalog page renders",
         %{conn: conn, workspace: workspace} do
      {:ok, _lv, html} = live(conn, ~p"/integrations/workspaces/#{workspace.slug}/new")

      assert html =~ "Add integration"
    end

    test "Given a workspace, when mounted, then provider cards are shown",
         %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/integrations/workspaces/#{workspace.slug}/new")

      assert has_element?(lv, "[data-role='provider-card']")
    end

    test "Given a workspace, when mounted, then Google Ads provider is listed",
         %{conn: conn, workspace: workspace} do
      {:ok, _lv, html} = live(conn, ~p"/integrations/workspaces/#{workspace.slug}/new")

      assert html =~ "Google Ads"
    end

    test "Given a workspace, when mounted, then Meta Ads provider is listed",
         %{conn: conn, workspace: workspace} do
      {:ok, _lv, html} = live(conn, ~p"/integrations/workspaces/#{workspace.slug}/new")

      assert html =~ "Meta Ads"
    end

    test "Given Ads providers, when mounted, then Ads category label is shown",
         %{conn: conn, workspace: workspace} do
      {:ok, _lv, html} = live(conn, ~p"/integrations/workspaces/#{workspace.slug}/new")

      assert html =~ "Ads"
    end

    test "Given a notifications stub, when mounted, then Notifications category label is shown",
         %{conn: conn, workspace: workspace} do
      {:ok, _lv, html} = live(conn, ~p"/integrations/workspaces/#{workspace.slug}/new")

      assert html =~ "Notifications"
    end

    test "Given an unregistered provider, when mounted, then it is not in the catalog",
         %{conn: conn, workspace: workspace} do
      {:ok, _lv, html} = live(conn, ~p"/integrations/workspaces/#{workspace.slug}/new")

      refute html =~ "Jira"
    end

    test "Given a workspace with an existing integration, when mounted, then Connect is still shown (multi-connection)",
         %{conn: conn, workspace: workspace, current_user: user} do
      Tenant.with_user!(user, fn ->
        integration_fixture(%{workspace_id: workspace.id, provider: :google_ads, status: :active})
      end)

      {:ok, lv, _html} = live(conn, ~p"/integrations/workspaces/#{workspace.slug}/new")

      assert has_element?(lv, "[data-role='connect-button']")
    end

    test "Given a workspace, when mounted, then Connect buttons are shown",
         %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/integrations/workspaces/#{workspace.slug}/new")

      assert has_element?(lv, "[data-role='connect-button']")
    end

    test "Given a workspace, when mounted, then a back link to the integrations list is present",
         %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/integrations/workspaces/#{workspace.slug}/new")

      assert has_element?(lv, ~s|a[href="/integrations/workspaces/#{workspace.slug}"]|)
    end
  end

  describe "access control" do
    test "Given an unauthenticated user, when accessing the catalog, then they are redirected",
         %{workspace: workspace} do
      conn = build_conn()

      assert {:error, {:redirect, %{to: "/identity/login"}}} =
               live(conn, ~p"/integrations/workspaces/#{workspace.slug}/new")
    end
  end

  describe "category labels" do
    test "renders 'Issue Tracking' label for issue_tracking-category provider",
         %{conn: conn, workspace: workspace} do
      {:ok, _lv, html} = live(conn, ~p"/integrations/workspaces/#{workspace.slug}/new")

      assert html =~ "Issue Tracking"
    end

    test "renders 'Status Page' label for status_page-category provider",
         %{conn: conn, workspace: workspace} do
      {:ok, _lv, html} = live(conn, ~p"/integrations/workspaces/#{workspace.slug}/new")

      assert html =~ "Status Page"
    end

    test "renders 'Calendar' label for calendar-category provider",
         %{conn: conn, workspace: workspace} do
      {:ok, _lv, html} = live(conn, ~p"/integrations/workspaces/#{workspace.slug}/new")

      assert html =~ "Calendar"
    end
  end
end
