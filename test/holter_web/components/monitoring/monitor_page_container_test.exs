defmodule HolterWeb.Components.Monitoring.MonitorPageContainerTest do
  use HolterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Phoenix.Component
  import HolterWeb.Components.Monitoring.MonitorPageContainer

  defp render_container(assigns) do
    ~H"""
    <.monitor_page_container>
      <:title>{@title}</:title>
      <:subtitle>{@subtitle}</:subtitle>
      <:actions>{@actions}</:actions>
      {@content}
    </.monitor_page_container>
    """
  end

  test "renders h-monitor-container wrapper" do
    html =
      render_component(&render_container/1, %{title: "", subtitle: "", actions: "", content: ""})

    assert html =~ "h-monitor-container"
  end

  test "renders data-role=page-title on the title row" do
    html =
      render_component(&render_container/1, %{title: "", subtitle: "", actions: "", content: ""})

    assert html =~ ~s(data-role="page-title")
  end

  test "renders title slot content" do
    html =
      render_component(&render_container/1, %{
        title: "Page Title Here",
        subtitle: "",
        actions: "",
        content: ""
      })

    assert html =~ "Page Title Here"
  end

  test "renders inner_block content" do
    html =
      render_component(&render_container/1, %{
        title: "",
        subtitle: "",
        actions: "",
        content: "Main content"
      })

    assert html =~ "Main content"
  end

  test "renders subtitle slot content when provided" do
    html =
      render_component(&render_container/1, %{
        title: "",
        subtitle: "sub text",
        actions: "",
        content: ""
      })

    assert html =~ "sub text"
  end

  test "renders actions slot content when provided" do
    html =
      render_component(&render_container/1, %{
        title: "",
        subtitle: "",
        actions: "action buttons",
        content: ""
      })

    assert html =~ "action buttons"
  end
end
