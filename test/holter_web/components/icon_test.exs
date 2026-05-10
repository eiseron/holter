defmodule HolterWeb.Components.IconTest do
  use HolterWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import HolterWeb.Components.Icon
  alias Phoenix.LiveView.JS

  defp doc(html), do: Floki.parse_fragment!(html)

  test "renders hero icon with name" do
    html = render_component(&icon/1, name: "hero-check", class: "w-5 h-5")
    assert html =~ "hero-check"
  end

  test "renders hero icon with class" do
    html = render_component(&icon/1, name: "hero-check", class: "w-5 h-5")
    assert html =~ "w-5 h-5"
  end

  test "renders monitor icon as inline svg with the screen path" do
    html = render_component(&icon/1, name: "monitor", class: "h-icon-size-8")

    assert doc(html) |> Floki.find("svg.h-icon-size-8 rect[x=2][y=3][width=20][height=14]") != []
  end

  test "renders bell icon as inline svg with the bell path" do
    html = render_component(&icon/1, name: "bell", class: "h-icon-size-8")

    assert doc(html) |> Floki.find("svg.h-icon-size-8 path[d^='M6 8a6 6 0 0 1 12 0']") != []
  end

  test "renders chart-bar icon as inline svg with three bars" do
    html = render_component(&icon/1, name: "chart-bar", class: "h-icon-size-8")

    assert doc(html) |> Floki.find("svg.h-icon-size-8 rect") |> length() == 3
  end

  test "renders shield-check icon as inline svg with the shield path" do
    html = render_component(&icon/1, name: "shield-check", class: "h-icon-size-8")

    assert doc(html) |> Floki.find("svg.h-icon-size-8 path[d^='M12 22s8-4']") != []
  end

  test "renders plus icon as inline svg with the plus path" do
    html = render_component(&icon/1, name: "plus")

    assert doc(html) |> Floki.find("svg path[d='M12 5v14M5 12h14']") != []
  end

  test "uses h-icon-size-4 as the default class when none is given" do
    html = render_component(&icon/1, name: "plus")

    assert doc(html) |> Floki.find("svg.h-icon-size-4") != []
  end

  test "marks inline svg icons aria-hidden so they are decorative" do
    html = render_component(&icon/1, name: "monitor")

    assert doc(html) |> Floki.find("svg[aria-hidden=true]") != []
  end

  test "show/2 returns JS struct without base" do
    assert %JS{} = show("#my-el")
  end

  test "show/2 returns JS struct with existing JS" do
    assert %JS{} = show(%JS{}, "#my-el")
  end

  test "hide/2 returns JS struct without base" do
    assert %JS{} = hide("#my-el")
  end

  test "hide/2 returns JS struct with existing JS" do
    assert %JS{} = hide(%JS{}, "#my-el")
  end
end
