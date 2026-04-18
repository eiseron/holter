defmodule HolterWeb.Components.EmptyStateTest do
  use HolterWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component
  import HolterWeb.Components.EmptyState

  defp render_empty_state(assigns) do
    ~H"""
    <.empty_state class={@class}>
      {@content}
    </.empty_state>
    """
  end

  test "renders empty state with base class" do
    html = render_component(&render_empty_state/1, %{class: "h-empty-state", content: "No data"})
    assert html =~ "h-empty-state"
  end

  test "renders empty state with content" do
    html =
      render_component(&render_empty_state/1, %{class: "h-empty-state", content: "No data found"})

    assert html =~ "No data found"
  end

  test "renders with custom class name" do
    html = render_component(&render_empty_state/1, %{class: "custom-empty", content: "Nothing"})
    assert html =~ "custom-empty"
  end

  test "renders with custom class and content" do
    html = render_component(&render_empty_state/1, %{class: "custom-empty", content: "Nothing"})
    assert html =~ "Nothing"
  end
end
