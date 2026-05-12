defmodule HolterWeb.Components.AuthScreenTest do
  use HolterWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component
  import HolterWeb.Components.AuthScreen

  defp doc(html), do: Floki.parse_fragment!(html)

  defp render_basic(assigns) do
    ~H"""
    <.auth_screen title={@title}>
      <p data-testid="body">Form would go here</p>
    </.auth_screen>
    """
  end

  defp render_with_footer(assigns) do
    ~H"""
    <.auth_screen title="Sign in">
      <p data-testid="body">Body</p>
      <:footer>
        <a href="/forgot" data-testid="footer-link">Forgot?</a>
      </:footer>
    </.auth_screen>
    """
  end

  defp render_titleless(assigns) do
    ~H"""
    <.auth_screen>
      <p data-testid="status">Verifying…</p>
    </.auth_screen>
    """
  end

  defp render_with_rest(assigns) do
    ~H"""
    <.auth_screen title="Sign in" data-testid="auth-root">
      <p>body</p>
    </.auth_screen>
    """
  end

  test "renders the title in an h1 with the title class when present" do
    html = render_component(&render_basic/1, %{title: "Sign in to Holter"})

    title =
      doc(html) |> Floki.find("h1.h-auth-screen-title") |> Floki.text() |> String.trim()

    assert title == "Sign in to Holter"
  end

  test "omits the h1 entirely when title is nil" do
    html = render_component(&render_titleless/1, %{})

    assert doc(html) |> Floki.find("h1.h-auth-screen-title") == []
  end

  test "renders the Holter brand mark sourced from /images/holter.svg inside the card" do
    html = render_component(&render_basic/1, %{title: "Sign in"})

    img = doc(html) |> Floki.find(".h-auth-screen-card img.h-auth-screen-logo")
    assert Floki.attribute(img, "src") == ["/images/holter.svg"]
  end

  test "labels the brand wordmark with alt='Holter' for screen readers" do
    html = render_component(&render_basic/1, %{title: "Sign in"})

    img = doc(html) |> Floki.find(".h-auth-screen-card img.h-auth-screen-logo")
    assert Floki.attribute(img, "alt") == ["Holter"]
  end

  test "renders the inner_block content inside the card" do
    html = render_component(&render_basic/1, %{title: "Sign in"})

    assert doc(html) |> Floki.find(".h-auth-screen-card p[data-testid=body]") != []
  end

  test "renders the footer slot inside the footer container when present" do
    html = render_component(&render_with_footer/1, %{})

    assert doc(html) |> Floki.find(".h-auth-screen-footer a[data-testid=footer-link]") != []
  end

  test "omits the footer container when the footer slot is empty" do
    html = render_component(&render_basic/1, %{title: "Sign in"})

    assert doc(html) |> Floki.find(".h-auth-screen-footer") == []
  end

  test "uses <section> as the root element with the wrapper class" do
    html = render_component(&render_basic/1, %{title: "Sign in"})

    assert doc(html) |> Floki.find("section.h-auth-screen") != []
  end

  test "forwards rest attributes to the root element" do
    html = render_component(&render_with_rest/1, %{})

    assert doc(html) |> Floki.find("section.h-auth-screen[data-testid=auth-root]") != []
  end
end
