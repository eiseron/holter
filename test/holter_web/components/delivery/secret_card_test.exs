defmodule HolterWeb.Components.Delivery.SecretCardTest do
  use HolterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import HolterWeb.Components.Delivery.SecretCard

  defp default_assigns do
    %{
      id: "signing",
      title: "Webhook signing",
      help: "Recompute HMAC-SHA256 over the body.",
      reveal_label: "Show signing token",
      value: "EXAMPLE_TOKEN_VALUE",
      regenerate_modal_id: "regenerate-secret-modal"
    }
  end

  defp render_card(overrides) do
    render_component(&secret_card/1, Map.merge(default_assigns(), overrides))
  end

  describe "secret_card/1" do
    test "renders the title heading with the prefixed id" do
      html = render_card(%{id: "signing"})
      assert html =~ ~s(id="signing-heading")
    end

    test "renders the title text inside the heading" do
      html = render_card(%{title: "Webhook signing"})
      assert html =~ "Webhook signing"
    end

    test "renders the help text" do
      html = render_card(%{help: "Recompute the HMAC over the body"})
      assert html =~ "Recompute the HMAC over the body"
    end

    test "renders the reveal summary text" do
      html = render_card(%{reveal_label: "Show signing token"})
      assert html =~ "Show signing token"
    end

    test "wraps the value inside a code element" do
      html = render_card(%{value: "EXAMPLE_TOKEN_VALUE"})
      assert html =~ ~r{<code>EXAMPLE_TOKEN_VALUE</code>}
    end

    test "the value pre carries the prefixed id so JS can target it" do
      html = render_card(%{id: "phishing"})
      assert html =~ ~s(id="phishing-value")
    end

    test "the value pre carries a matching data-testid" do
      html = render_card(%{id: "phishing"})
      assert html =~ ~s(data-testid="phishing-value")
    end

    test "the Copy button references the value id in its onclick" do
      html = render_card(%{id: "signing"})
      assert html =~ ~r/getElementById\(&#39;signing-value&#39;\)/
    end

    test "the Regenerate button targets the configured modal id" do
      html = render_card(%{regenerate_modal_id: "custom-modal"})
      assert html =~ "custom-modal"
    end
  end
end
