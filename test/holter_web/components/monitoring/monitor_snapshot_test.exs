defmodule HolterWeb.Components.Monitoring.MonitorSnapshotTest do
  use HolterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import HolterWeb.Components.Monitoring.MonitorSnapshot

  defp base_snapshot(overrides \\ %{}) do
    Map.merge(
      %{
        "url" => "https://example.com",
        "method" => "get",
        "interval_seconds" => 60,
        "timeout_seconds" => 30,
        "follow_redirects" => false,
        "ssl_ignore" => false
      },
      overrides
    )
  end

  describe "required fields" do
    test "renders URL" do
      html = render_component(&monitor_snapshot/1, snapshot: base_snapshot())
      assert html =~ "https://example.com"
    end

    test "renders method uppercased" do
      html = render_component(&monitor_snapshot/1, snapshot: base_snapshot())
      assert html =~ "GET"
    end

    test "renders interval_seconds" do
      html = render_component(&monitor_snapshot/1, snapshot: base_snapshot())
      assert html =~ "60s"
    end

    test "renders timeout_seconds" do
      html = render_component(&monitor_snapshot/1, snapshot: base_snapshot())
      assert html =~ "30s"
    end
  end

  describe "conditional sections" do
    test "renders max_redirects when follow_redirects is true" do
      snapshot = base_snapshot(%{"follow_redirects" => true, "max_redirects" => 5})
      html = render_component(&monitor_snapshot/1, snapshot: snapshot)
      assert html =~ "Max Redirects"
    end

    test "does not render max_redirects when follow_redirects is false" do
      html = render_component(&monitor_snapshot/1, snapshot: base_snapshot())
      refute html =~ "Max Redirects"
    end

    test "renders SSL ignore badge when ssl_ignore is true" do
      snapshot = base_snapshot(%{"ssl_ignore" => true})
      html = render_component(&monitor_snapshot/1, snapshot: snapshot)
      assert html =~ "Ignore SSL"
    end

    test "does not render SSL section when ssl_ignore is false" do
      html = render_component(&monitor_snapshot/1, snapshot: base_snapshot())
      refute html =~ "Ignore SSL"
    end

    test "renders custom headers as pretty JSON when present" do
      snapshot = base_snapshot(%{"headers" => %{"Authorization" => "Bearer token"}})
      html = render_component(&monitor_snapshot/1, snapshot: snapshot)
      assert html =~ "Authorization"
    end

    test "does not render headers section when headers is empty map" do
      snapshot = base_snapshot(%{"headers" => %{}})
      html = render_component(&monitor_snapshot/1, snapshot: snapshot)
      refute html =~ "Custom Headers"
    end

    test "renders request body when present" do
      snapshot = base_snapshot(%{"body" => ~s({"key":"val"})})
      html = render_component(&monitor_snapshot/1, snapshot: snapshot)
      assert html =~ "Request Body"
    end

    test "does not render body section when body is empty string" do
      snapshot = base_snapshot(%{"body" => ""})
      html = render_component(&monitor_snapshot/1, snapshot: snapshot)
      refute html =~ "Request Body"
    end

    test "renders keyword_positive rules when present" do
      snapshot = base_snapshot(%{"keyword_positive" => ["Success", "OK"]})
      html = render_component(&monitor_snapshot/1, snapshot: snapshot)
      assert html =~ "Must Contain"
    end

    test "renders keyword_negative rules when present" do
      snapshot = base_snapshot(%{"keyword_negative" => ["hacked"]})
      html = render_component(&monitor_snapshot/1, snapshot: snapshot)
      assert html =~ "Must Not Contain"
    end
  end
end
