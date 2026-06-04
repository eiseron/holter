defmodule HolterWeb.Components.Integrations.IntegrationStatusBadgeTest do
  use HolterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import HolterWeb.Components.Integrations.IntegrationStatusBadge

  describe "container" do
    test "renders h-badge class" do
      html = render_component(&integration_status_badge/1, status: :active)
      assert html =~ "h-badge"
    end

    test "renders data-role integration-status anchor" do
      html = render_component(&integration_status_badge/1, status: :active)
      assert html =~ ~s(data-role="integration-status")
    end
  end

  describe ":active status" do
    test "applies success class" do
      html = render_component(&integration_status_badge/1, status: :active)
      assert html =~ "h-badge-success"
    end

    test "renders Connected label" do
      html = render_component(&integration_status_badge/1, status: :active)
      assert html =~ "Connected"
    end
  end

  describe ":reauth_required status" do
    test "applies warning class" do
      html = render_component(&integration_status_badge/1, status: :reauth_required)
      assert html =~ "h-badge-warning"
    end

    test "renders Reconnect needed label" do
      html = render_component(&integration_status_badge/1, status: :reauth_required)
      assert html =~ "Reconnect needed"
    end
  end

  describe ":rate_limited status" do
    test "applies warning class" do
      html = render_component(&integration_status_badge/1, status: :rate_limited)
      assert html =~ "h-badge-warning"
    end

    test "renders Rate limited label" do
      html = render_component(&integration_status_badge/1, status: :rate_limited)
      assert html =~ "Rate limited"
    end
  end

  describe ":disabled status" do
    test "applies neutral class" do
      html = render_component(&integration_status_badge/1, status: :disabled)
      assert html =~ "h-badge-neutral"
    end

    test "renders Disabled label" do
      html = render_component(&integration_status_badge/1, status: :disabled)
      assert html =~ "Disabled"
    end
  end

  describe ":provider_down status" do
    test "applies danger class" do
      html = render_component(&integration_status_badge/1, status: :provider_down)
      assert html =~ "h-badge-danger"
    end

    test "renders Provider down label" do
      html = render_component(&integration_status_badge/1, status: :provider_down)
      assert html =~ "Provider down"
    end
  end
end
