defmodule HolterWeb.Components.EmptyStateTest do
  use HolterWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component
  import HolterWeb.Components.EmptyState

  defp doc(html), do: Floki.parse_fragment!(html)

  defp render_basic(assigns) do
    ~H"""
    <.empty_state title={@title} description={@description} variant={@variant} />
    """
  end

  defp render_with_icon(assigns) do
    ~H"""
    <.empty_state title="No items">
      <:icon>
        <svg data-testid="my-svg" />
      </:icon>
    </.empty_state>
    """
  end

  defp render_with_actions(assigns) do
    ~H"""
    <.empty_state title="No items">
      <:actions>
        <a href="/new" data-testid="my-action">New</a>
      </:actions>
    </.empty_state>
    """
  end

  defp render_with_rest(assigns) do
    ~H"""
    <.empty_state title="No items" data-testid="my-empty-state" />
    """
  end

  defp render_with_inner_block(assigns) do
    ~H"""
    <.empty_state>
      <p data-testid="fallback">Custom content</p>
    </.empty_state>
    """
  end

  defp render_with_inner_block_and_title(assigns) do
    ~H"""
    <.empty_state title="Has title">
      <p data-testid="fallback">Should not render</p>
    </.empty_state>
    """
  end

  test "renders the title in an h2 with the title class" do
    html =
      render_component(&render_basic/1, %{
        title: "No monitors yet",
        description: nil,
        variant: "default"
      })

    title = doc(html) |> Floki.find("h2.h-empty-state-title") |> Floki.text() |> String.trim()
    assert title == "No monitors yet"
  end

  test "renders the description in a p with the description class" do
    html =
      render_component(&render_basic/1, %{
        title: nil,
        description: "Create one to get started.",
        variant: "default"
      })

    description =
      doc(html) |> Floki.find("p.h-empty-state-description") |> Floki.text() |> String.trim()

    assert description == "Create one to get started."
  end

  test "renders the icon slot inside the icon container when present" do
    html = render_component(&render_with_icon/1, %{})

    assert doc(html) |> Floki.find(".h-empty-state-icon svg[data-testid=my-svg]") != []
  end

  test "omits the icon container when the icon slot is empty" do
    html =
      render_component(&render_basic/1, %{
        title: "No items",
        description: nil,
        variant: "default"
      })

    assert doc(html) |> Floki.find(".h-empty-state-icon") == []
  end

  test "renders the actions slot inside the actions container when present" do
    html = render_component(&render_with_actions/1, %{})

    assert doc(html) |> Floki.find(".h-empty-state-actions a[data-testid=my-action]") != []
  end

  test "omits the actions container when the actions slot is empty" do
    html =
      render_component(&render_basic/1, %{
        title: "No items",
        description: nil,
        variant: "default"
      })

    assert doc(html) |> Floki.find(".h-empty-state-actions") == []
  end

  test "applies only the default variant class when variant is default" do
    html =
      render_component(&render_basic/1, %{
        title: "No items",
        description: nil,
        variant: "default"
      })

    root_classes =
      doc(html) |> Floki.find("section.h-empty-state") |> Floki.attribute("class") |> List.first()

    assert root_classes =~ "h-empty-state-default"
    refute root_classes =~ "h-empty-state-boxed"
  end

  test "applies the boxed variant class when variant is boxed" do
    html =
      render_component(&render_basic/1, %{
        title: "No items",
        description: nil,
        variant: "boxed"
      })

    root_classes =
      doc(html) |> Floki.find("section.h-empty-state") |> Floki.attribute("class") |> List.first()

    assert root_classes =~ "h-empty-state-boxed"
  end

  test "sets role=status on the root for screen readers" do
    html =
      render_component(&render_basic/1, %{
        title: "No items",
        description: nil,
        variant: "default"
      })

    assert doc(html) |> Floki.find("section.h-empty-state[role=status]") != []
  end

  test "renders inner_block fallback when title and description are nil" do
    html = render_component(&render_with_inner_block/1, %{})

    assert doc(html) |> Floki.find("section.h-empty-state p[data-testid=fallback]") != []
  end

  test "skips inner_block when title is provided" do
    html = render_component(&render_with_inner_block_and_title/1, %{})

    assert doc(html) |> Floki.find("p[data-testid=fallback]") == []
  end

  test "forwards rest attributes to the root element" do
    html = render_component(&render_with_rest/1, %{})

    assert doc(html) |> Floki.find("section.h-empty-state[data-testid=my-empty-state]") != []
  end
end
