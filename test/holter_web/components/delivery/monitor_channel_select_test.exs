defmodule HolterWeb.Components.Delivery.MonitorChannelSelectTest do
  use HolterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import HolterWeb.Components.Delivery.MonitorChannelSelect

  defp monitor(id, url) do
    %{id: id, url: url}
  end

  describe "monitor_channel_select/1 — empty state" do
    test "renders empty state when monitors list is empty" do
      html = render_component(&monitor_channel_select/1, monitors: [], selected_ids: [])
      assert html =~ "No monitors in this workspace yet"
    end

    test "does not render checkboxes when monitors list is empty" do
      html = render_component(&monitor_channel_select/1, monitors: [], selected_ids: [])
      refute html =~ ~s(type="checkbox")
    end
  end

  describe "monitor_channel_select/1 — monitor list" do
    test "renders first monitor url" do
      monitors = [monitor("id-1", "https://alpha.local"), monitor("id-2", "https://beta.local")]
      html = render_component(&monitor_channel_select/1, monitors: monitors, selected_ids: [])
      assert html =~ "https://alpha.local"
    end

    test "renders second monitor url" do
      monitors = [monitor("id-1", "https://alpha.local"), monitor("id-2", "https://beta.local")]
      html = render_component(&monitor_channel_select/1, monitors: monitors, selected_ids: [])
      assert html =~ "https://beta.local"
    end

    test "unchecked monitors do not have checked attribute" do
      monitors = [monitor("id-1", "https://alpha.local")]
      html = render_component(&monitor_channel_select/1, monitors: monitors, selected_ids: [])
      refute html =~ ~s(checked)
    end

    test "selected monitors have checked attribute" do
      monitors = [monitor("id-1", "https://alpha.local"), monitor("id-2", "https://beta.local")]

      html =
        render_component(&monitor_channel_select/1, monitors: monitors, selected_ids: ["id-1"])

      assert html =~ ~s(checked)
    end

    test "selected monitors get the checked modifier class" do
      monitors = [monitor("id-1", "https://alpha.local"), monitor("id-2", "https://beta.local")]

      html =
        render_component(&monitor_channel_select/1, monitors: monitors, selected_ids: ["id-1"])

      assert html =~ "h-monitor-select-item--checked"
    end

    test "only selected monitors get the checked modifier class" do
      monitors = [monitor("id-1", "https://alpha.local"), monitor("id-2", "https://beta.local")]

      html =
        render_component(&monitor_channel_select/1, monitors: monitors, selected_ids: ["id-1"])

      assert Regex.scan(~r/h-monitor-select-item--checked/, html) |> length() == 1
    end

    test "uses default input name monitor_ids[]" do
      monitors = [monitor("id-1", "https://alpha.local")]
      html = render_component(&monitor_channel_select/1, monitors: monitors, selected_ids: [])
      assert html =~ ~s(name="monitor_ids[]")
    end

    test "uses custom input_name when provided" do
      monitors = [monitor("id-1", "https://alpha.local")]

      html =
        render_component(&monitor_channel_select/1,
          monitors: monitors,
          selected_ids: [],
          input_name: "custom[]"
        )

      assert html =~ ~s(name="custom[]")
    end
  end
end
