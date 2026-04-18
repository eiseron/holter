defmodule HolterWeb.Components.TooltipTest do
  use HolterWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component
  import HolterWeb.Components.Tooltip

  defp render_tooltip(assigns) do
    ~H"""
    <.tooltip text={@text}>
      {@content}
    </.tooltip>
    """
  end

  test "renders tooltip text" do
    html = render_component(&render_tooltip/1, %{text: "My Tooltip", content: "Hover me"})
    assert html =~ "My Tooltip"
  end

  test "renders tooltip inner content" do
    html = render_component(&render_tooltip/1, %{text: "My Tooltip", content: "Hover me"})
    assert html =~ "Hover me"
  end
end
