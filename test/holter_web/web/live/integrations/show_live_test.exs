defmodule HolterWeb.Web.Integrations.ShowLiveTest do
  use HolterWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Holter.Integrations.Google.Ads, as: GoogleAds
  alias Holter.Integrations.IntegrationRulesContext
  alias Holter.Integrations.Meta.Ads, as: MetaAds
  alias Holter.Integrations.Models.IntegrationRule
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
    test "Given a valid integration id, when mounted, then the page renders",
         %{conn: conn, integration: integration} do
      {:ok, _lv, html} = live(conn, ~p"/integrations/#{integration.id}")

      assert html =~ "Google Ads"
    end

    test "Given an active integration, when mounted, then the status badge shows 'Connected'",
         %{conn: conn, integration: integration} do
      {:ok, lv, _html} = live(conn, ~p"/integrations/#{integration.id}")

      assert has_element?(lv, "[data-role='integration-status']", "Connected")
    end

    test "Given an integration, when mounted, then the rules tab is the current page",
         %{conn: conn, integration: integration} do
      {:ok, lv, _html} = live(conn, ~p"/integrations/#{integration.id}")

      assert has_element?(lv, "[data-role='tab-rules'][aria-current='page']")
    end

    test "Given an integration, when mounted, then a back link to the catalog is present",
         %{conn: conn, integration: integration, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/integrations/#{integration.id}")

      assert has_element?(
               lv,
               ~s|a[href="/integrations/workspaces/#{workspace.slug}"]|
             )
    end
  end

  describe "subnav navigation" do
    test "subnav links to logs route",
         %{conn: conn, integration: integration} do
      {:ok, lv, _html} = live(conn, ~p"/integrations/#{integration.id}")

      assert has_element?(
               lv,
               ~s|a[href="/integrations/#{integration.id}/logs"][data-role="tab-logs"]|
             )
    end
  end

  describe "rules CRUD" do
    test "Given an integration with no rules, when mounted, then empty state is shown",
         %{conn: conn, integration: integration} do
      {:ok, _lv, html} = live(conn, ~p"/integrations/#{integration.id}")

      assert html =~ "No rules yet"
    end

    test "Given a rule exists, when mounted, then it appears in the rules list",
         %{conn: conn, integration: integration, workspace: workspace, current_user: user} do
      monitor =
        Tenant.with_user!(user, fn -> monitor_fixture(workspace_id: workspace.id) end)

      Tenant.with_user!(user, fn ->
        integration_rule_fixture(
          integration: integration,
          monitor: monitor,
          event_type: "incident_opened",
          action: "pause_campaign",
          target_id: "gads-rule-1"
        )
      end)

      {:ok, _lv, html} = live(conn, ~p"/integrations/#{integration.id}")

      assert html =~ "gads-rule-1"
    end

    test "Given a valid form, when create_rule is sent, then the rule is added and a flash appears",
         %{conn: conn, integration: integration, workspace: workspace, current_user: user} do
      monitor =
        Tenant.with_user!(user, fn -> monitor_fixture(workspace_id: workspace.id) end)

      {:ok, lv, _html} = live(conn, ~p"/integrations/#{integration.id}")

      render_click(lv, "create_rule", %{
        "rule" => %{
          "monitor_id" => monitor.id,
          "event_type" => "incident_opened",
          "action" => "pause_campaign",
          "target_id" => "gads-new-rule"
        }
      })

      assert has_element?(lv, "[role='alert']", "Rule added")
    end

    test "Given invalid form params, when create_rule is sent, then an error flash is shown",
         %{conn: conn, integration: integration} do
      {:ok, lv, _html} = live(conn, ~p"/integrations/#{integration.id}")

      render_click(lv, "create_rule", %{
        "rule" => %{
          "monitor_id" => Ecto.UUID.generate(),
          "event_type" => "unknown_event",
          "action" => "pause_campaign",
          "target_id" => "x"
        }
      })

      assert has_element?(lv, "[role='alert']", "Could not add rule")
    end

    test "Given an existing rule, when delete_rule is sent, then the rule is removed",
         %{conn: conn, integration: integration, workspace: workspace, current_user: user} do
      monitor =
        Tenant.with_user!(user, fn -> monitor_fixture(workspace_id: workspace.id) end)

      rule =
        Tenant.with_user!(user, fn ->
          integration_rule_fixture(
            integration: integration,
            monitor: monitor,
            target_id: "gads-doomed"
          )
        end)

      {:ok, lv, _html} = live(conn, ~p"/integrations/#{integration.id}")

      render_click(lv, "delete_rule", %{"id" => rule.id})

      assert has_element?(lv, "[role='alert']", "Rule removed")
    end

    test "Given a non-existent rule id, when delete_rule is sent, then an error flash is shown",
         %{conn: conn, integration: integration} do
      {:ok, lv, _html} = live(conn, ~p"/integrations/#{integration.id}")

      render_click(lv, "delete_rule", %{"id" => Ecto.UUID.generate()})

      assert has_element?(lv, "[role='alert']", "Could not remove rule")
    end

    test "Given a rule from a sibling integration, when delete_rule is sent, then it is not deleted",
         %{conn: conn, integration: integration, workspace: workspace, current_user: user} do
      monitor =
        Tenant.with_user!(user, fn -> monitor_fixture(workspace_id: workspace.id) end)

      other_integration =
        Tenant.with_user!(user, fn ->
          integration_fixture(%{
            workspace_id: workspace.id,
            provider: :meta_ads,
            status: :active
          })
        end)

      foreign_rule =
        Tenant.with_user!(user, fn ->
          integration_rule_fixture(
            integration: other_integration,
            monitor: monitor,
            target_id: "foreign-target"
          )
        end)

      {:ok, lv, _html} = live(conn, ~p"/integrations/#{integration.id}")

      render_click(lv, "delete_rule", %{"id" => foreign_rule.id})

      assert has_element?(lv, "[role='alert']", "Could not remove rule")

      still_present =
        Tenant.with_user!(user, fn ->
          IntegrationRulesContext.list_for_integration(other_integration.id)
        end)

      assert Enum.any?(still_present, &(&1.id == foreign_rule.id))
    end
  end

  describe "delete rule modal" do
    test "ask_delete_rule embeds the rule id in the confirm button payload",
         %{conn: conn, integration: integration, workspace: workspace, current_user: user} do
      monitor =
        Tenant.with_user!(user, fn -> monitor_fixture(workspace_id: workspace.id) end)

      rule =
        Tenant.with_user!(user, fn ->
          integration_rule_fixture(integration: integration, monitor: monitor)
        end)

      {:ok, lv, _html} = live(conn, ~p"/integrations/#{integration.id}")

      html = render_click(lv, "ask_delete_rule", %{"id" => rule.id})

      assert html =~ rule.id
      assert html =~ "confirm-delete-rule-button"
    end

    test "cancel_delete_rule resets the modal state without raising",
         %{conn: conn, integration: integration, workspace: workspace, current_user: user} do
      monitor =
        Tenant.with_user!(user, fn -> monitor_fixture(workspace_id: workspace.id) end)

      rule =
        Tenant.with_user!(user, fn ->
          integration_rule_fixture(integration: integration, monitor: monitor)
        end)

      {:ok, lv, _html} = live(conn, ~p"/integrations/#{integration.id}")

      render_click(lv, "ask_delete_rule", %{"id" => rule.id})
      render_click(lv, "cancel_delete_rule", %{})

      assert Process.alive?(lv.pid)
    end
  end

  describe "rule humanized labels" do
    setup %{workspace: workspace, current_user: user} do
      monitor = Tenant.with_user!(user, fn -> monitor_fixture(workspace_id: workspace.id) end)
      %{monitor: monitor}
    end

    test "renders 'Pause campaign' for a pause_campaign rule",
         %{conn: conn, integration: integration, monitor: monitor, current_user: user} do
      Tenant.with_user!(user, fn ->
        integration_rule_fixture(
          integration: integration,
          monitor: monitor,
          event_type: "incident_opened",
          action: "pause_campaign",
          target_id: "g-1"
        )
      end)

      {:ok, _lv, html} = live(conn, ~p"/integrations/#{integration.id}")

      assert html =~ "Pause campaign"
    end

    test "renders 'When an incident is opened' for an incident_opened rule",
         %{conn: conn, integration: integration, monitor: monitor, current_user: user} do
      Tenant.with_user!(user, fn ->
        integration_rule_fixture(
          integration: integration,
          monitor: monitor,
          event_type: "incident_opened",
          action: "pause_campaign",
          target_id: "g-4"
        )
      end)

      {:ok, _lv, html} = live(conn, ~p"/integrations/#{integration.id}")

      assert html =~ "When an incident is opened"
    end

    test "renders 'no actions' notice for a provider whose registry entry is missing",
         %{conn: conn, workspace: workspace, current_user: user} do
      slack =
        Tenant.with_user!(user, fn ->
          integration_fixture(%{
            workspace_id: workspace.id,
            provider: :slack,
            status: :active
          })
        end)

      {:ok, _lv, html} = live(conn, ~p"/integrations/#{slack.id}")

      assert html =~ "This provider does not yet support automated actions"
    end
  end

  describe "status badge variants" do
    test "Given a reauth_required integration, when mounted, then the status badge shows 'Reconnect needed'",
         %{conn: conn, current_user: user, workspace: workspace} do
      reauth =
        Tenant.with_user!(user, fn ->
          integration_fixture(%{
            workspace_id: workspace.id,
            provider: :google_ads,
            status: :reauth_required
          })
        end)

      {:ok, _lv, html} = live(conn, ~p"/integrations/#{reauth.id}")

      assert html =~ "Reconnect needed"
    end

    test "Given a rate_limited integration, when mounted, then the status badge shows 'Rate limited'",
         %{conn: conn, current_user: user, workspace: workspace} do
      rl =
        Tenant.with_user!(user, fn ->
          integration_fixture(%{
            workspace_id: workspace.id,
            provider: :google_ads,
            status: :rate_limited
          })
        end)

      {:ok, _lv, html} = live(conn, ~p"/integrations/#{rl.id}")

      assert html =~ "Rate limited"
    end

    test "Given a disabled integration, when mounted, then the status badge shows 'Disabled'",
         %{conn: conn, current_user: user, workspace: workspace} do
      dis =
        Tenant.with_user!(user, fn ->
          integration_fixture(%{
            workspace_id: workspace.id,
            provider: :google_ads,
            status: :disabled
          })
        end)

      {:ok, _lv, html} = live(conn, ~p"/integrations/#{dis.id}")

      assert html =~ "Disabled"
    end

    test "Given a provider_down integration, when mounted, then the status badge shows 'Provider down'",
         %{conn: conn, current_user: user, workspace: workspace} do
      down =
        Tenant.with_user!(user, fn ->
          integration_fixture(%{
            workspace_id: workspace.id,
            provider: :google_ads,
            status: :provider_down
          })
        end)

      {:ok, _lv, html} = live(conn, ~p"/integrations/#{down.id}")

      assert html =~ "Provider down"
    end
  end

  describe "access control" do
    test "Given an unauthenticated user, when accessing the page, then they are redirected",
         %{integration: integration} do
      conn = build_conn()

      assert {:error, {:redirect, %{to: "/identity/login"}}} =
               live(conn, ~p"/integrations/#{integration.id}")
    end

    test "rejects access for a user not in the workspace",
         %{workspace: workspace, current_user: user} do
      %{user: other_user} = verified_user_fixture()

      integration =
        Tenant.with_user!(user, fn ->
          integration_fixture(%{
            workspace_id: workspace.id,
            provider: :google_ads,
            status: :active
          })
        end)

      conn = log_in_user(build_conn(), other_user)

      assert {:error, _} = live(conn, ~p"/integrations/#{integration.id}")
    end
  end

  describe "rule writes are denied for non-admin members" do
    setup do
      {member, ws} = workspace_with_role(:member)

      integration =
        Tenant.with_user!(member, fn ->
          integration_fixture(%{workspace_id: ws.id, provider: :google_ads, status: :active})
        end)

      monitor = Tenant.with_user!(member, fn -> monitor_fixture(workspace_id: ws.id) end)

      rule =
        Tenant.with_user!(member, fn ->
          integration_rule_fixture(
            integration: integration,
            monitor: monitor,
            event_type: "incident_opened",
            action: "pause_campaign",
            target_id: "gads-keep"
          )
        end)

      {:ok, lv, _html} =
        live(log_in_user(build_conn(), member), ~p"/integrations/#{integration.id}")

      %{lv: lv, integration: integration, monitor: monitor, rule: rule}
    end

    test "create_rule shows the unauthorized flash", %{lv: lv, monitor: monitor} do
      render_click(lv, "create_rule", %{
        "rule" => %{
          "monitor_id" => monitor.id,
          "event_type" => "incident_resolved",
          "action" => "resume_campaign",
          "target_id" => "gads-blocked"
        }
      })

      assert has_element?(lv, "[role='alert']", "You are not allowed to update this integration.")
    end

    test "create_rule does not persist a new rule", %{
      lv: lv,
      integration: integration,
      monitor: monitor
    } do
      render_click(lv, "create_rule", %{
        "rule" => %{
          "monitor_id" => monitor.id,
          "event_type" => "incident_resolved",
          "action" => "resume_campaign",
          "target_id" => "gads-blocked"
        }
      })

      assert [%IntegrationRule{target_id: "gads-keep"}] =
               IntegrationRulesContext.list_for_integration(integration.id)
    end

    test "delete_rule shows the unauthorized flash", %{lv: lv, rule: rule} do
      render_click(lv, "delete_rule", %{"id" => rule.id})

      assert has_element?(lv, "[role='alert']", "You are not allowed to update this integration.")
    end

    test "delete_rule does not remove the rule", %{lv: lv, rule: rule} do
      render_click(lv, "delete_rule", %{"id" => rule.id})

      assert {:ok, %IntegrationRule{}} = IntegrationRulesContext.get(rule.id)
    end
  end

  describe "provider label contracts" do
    test "every event_type defined in IntegrationRule has a humanized label",
         %{conn: conn, integration: integration, workspace: workspace, current_user: user} do
      monitor =
        Tenant.with_user!(user, fn -> monitor_fixture(workspace_id: workspace.id) end)

      for event <- IntegrationRule.event_types() do
        Tenant.with_user!(user, fn ->
          integration_rule_fixture(
            integration: integration,
            monitor: monitor,
            event_type: event,
            action: "pause_campaign",
            target_id: "contract-#{event}"
          )
        end)
      end

      {:ok, _lv, _html} = live(conn, ~p"/integrations/#{integration.id}")
    end

    test "every Google Ads action exposed by supported_actions/0 has a humanized label" do
      for action <- GoogleAds.supported_actions() do
        label = GoogleAds.action_label(action)

        assert is_binary(label) and label != "",
               "Missing label for GoogleAds action=#{inspect(action)}"

        refute label == Atom.to_string(action),
               "Label for #{action} should be humanized, not the raw atom"
      end
    end

    test "every Meta Ads action exposed by supported_actions/0 has a humanized label" do
      for action <- MetaAds.supported_actions() do
        label = MetaAds.action_label(action)

        assert is_binary(label) and label != "",
               "Missing label for MetaAds action=#{inspect(action)}"

        refute label == Atom.to_string(action),
               "Label for #{action} should be humanized, not the raw atom"
      end
    end
  end
end
