defmodule HolterWeb.Components.ListTest do
  use HolterWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component
  import HolterWeb.Components.List

  defp render_list(assigns) do
    ~H"""
    <.list>
      <:item :for={item <- @items} title={item.title}>{item.content}</:item>
    </.list>
    """
  end

  test "renders list with item title" do
    items = [%{title: "My Title", content: "My Content"}]
    html = render_component(&render_list/1, %{items: items})
    assert html =~ "My Title"
  end

  test "renders list with item content" do
    items = [%{title: "My Title", content: "My Content"}]
    html = render_component(&render_list/1, %{items: items})
    assert html =~ "My Content"
  end

  test "renders first item in list" do
    items = [
      %{title: "Item 1", content: "Content 1"},
      %{title: "Item 2", content: "Content 2"}
    ]

    html = render_component(&render_list/1, %{items: items})
    assert html =~ "Item 1"
  end

  test "renders second item in list" do
    items = [
      %{title: "Item 1", content: "Content 1"},
      %{title: "Item 2", content: "Content 2"}
    ]

    html = render_component(&render_list/1, %{items: items})
    assert html =~ "Item 2"
  end
end
