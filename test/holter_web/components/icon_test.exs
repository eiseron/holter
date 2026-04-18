defmodule HolterWeb.Components.IconTest do
  use HolterWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import HolterWeb.Components.Icon
  alias Phoenix.LiveView.JS

  test "renders hero icon with name" do
    html = render_component(&icon/1, name: "hero-check", class: "w-5 h-5")
    assert html =~ "hero-check"
  end

  test "renders hero icon with class" do
    html = render_component(&icon/1, name: "hero-check", class: "w-5 h-5")
    assert html =~ "w-5 h-5"
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
