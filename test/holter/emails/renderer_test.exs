defmodule Holter.Emails.RendererTest do
  use ExUnit.Case, async: true

  use Phoenix.Component

  alias Holter.Emails.{Components, Layout, Renderer}

  attr :locale, :string, required: true
  attr :name, :string, required: true

  defp sample_html(assigns) do
    ~H"""
    <Layout.html title="Test message" preheader="Pre" locale={@locale}>
      <h1>Hello {@name}</h1>
      <Components.cta_button href="https://app.holter.test/verify">Click</Components.cta_button>
    </Layout.html>
    """
  end

  defp render_sample(overrides \\ %{}) do
    Renderer.to_html(&sample_html/1, Map.merge(%{locale: "en", name: "Ada"}, overrides))
  end

  describe "to_html/2 wrapping with the layout" do
    test "places the Holter brand wordmark above the message body" do
      html = render_sample()

      brand_pos = :binary.match(html, "Holter") |> elem(0)
      body_pos = :binary.match(html, "Hello Ada") |> elem(0)

      assert brand_pos < body_pos
    end

    test "renders the inner block content provided by the caller" do
      assert render_sample(%{name: "Marie"}) =~ "Hello Marie"
    end

    test "sets the document lang attribute from the locale assign" do
      assert render_sample(%{locale: "pt_BR"}) =~ ~s(lang="pt_BR")
    end

    test "prepends a DOCTYPE so mail clients render in standards mode" do
      assert String.starts_with?(render_sample(), "<!DOCTYPE html>")
    end
  end

  describe "to_html/2 inline styles" do
    test "carries inline style attributes on visible elements" do
      assert render_sample() =~ ~s(style=")
    end

    test "applies the Holter brand accent color directly in inline styles" do
      assert render_sample() =~ "#37b9ff"
    end

    test "embeds the CTA button anchor with the provided href" do
      assert render_sample() =~ ~s(href="https://app.holter.test/verify")
    end

    test "ships no <style> block — every rule is authored inline" do
      refute render_sample() =~ "<style"
    end

    test "scrubs Phoenix LiveView dev annotations (data-phx-loc) from the output" do
      refute render_sample() =~ "data-phx-loc"
    end
  end

  describe "Layout.text/2" do
    test "opens with the Holter wordmark" do
      assert String.starts_with?(Layout.text("Welcome, Ada."), "Holter")
    end

    test "includes the body the caller supplied" do
      assert Layout.text("Welcome, Ada.") =~ "Welcome, Ada."
    end

    test "closes with the Eiseron-attributed tagline" do
      assert Layout.text("hi") =~ "Eiseron"
    end

    test "ends with a trailing newline so mail clients render cleanly" do
      assert String.ends_with?(Layout.text("hi"), "\n")
    end

    test "orders the optional footer between the body and the tagline" do
      output = Layout.text("body line", footer: "footer line")
      {body_pos, _} = :binary.match(output, "body line")
      {footer_pos, _} = :binary.match(output, "footer line")
      {tagline_pos, _} = :binary.match(output, "Eiseron")

      assert body_pos < footer_pos and footer_pos < tagline_pos
    end
  end

  describe "Components.anti_phishing_footer/1" do
    test "renders the verification code passed in" do
      assert Renderer.to_html(&Components.anti_phishing_footer/1, %{code: "abc-123"}) =~
               "abc-123"
    end

    test "labels the printed code as a verification code" do
      assert Renderer.to_html(&Components.anti_phishing_footer/1, %{code: "abc-123"}) =~
               "Verification code"
    end

    test "renders nothing when no code is given" do
      refute Renderer.to_html(&Components.anti_phishing_footer/1, %{code: nil}) =~
               "Verification code"
    end
  end
end
