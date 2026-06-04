defmodule HolterWeb.Components.Integrations.ProviderLogoTest do
  use HolterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import HolterWeb.Components.Integrations.ProviderLogo

  describe "known providers" do
    test "renders an img tag with the static asset path for google_ads" do
      html = render_component(&provider_logo/1, provider: :google_ads)
      assert html =~ ~s(src="/images/integrations/google_ads.svg")
    end

    test "renders an img tag with the static asset path for meta_ads" do
      html = render_component(&provider_logo/1, provider: :meta_ads)
      assert html =~ ~s(src="/images/integrations/meta_ads.svg")
    end

    test "carries the data-role anchor for tests and theming" do
      html = render_component(&provider_logo/1, provider: :google_ads)
      assert html =~ ~s(data-role="provider-logo")
    end

    test "uses the humanized provider name as default alt text" do
      html = render_component(&provider_logo/1, provider: :google_ads)
      assert html =~ ~s(alt="Google Ads")
    end

    test "honours a custom alt attribute when given" do
      html = render_component(&provider_logo/1, provider: :google_ads, alt: "My Account")
      assert html =~ ~s(alt="My Account")
    end
  end

  describe "unknown providers" do
    test "falls back to a placeholder without raising" do
      html = render_component(&provider_logo/1, provider: :slack)
      assert html =~ "h-provider-logo-placeholder"
      refute html =~ ~s(src="/images/integrations/slack.svg")
    end

    test "placeholder is aria-hidden so screen readers skip it" do
      html = render_component(&provider_logo/1, provider: :linear)
      assert html =~ ~s(aria-hidden="true")
    end
  end
end
