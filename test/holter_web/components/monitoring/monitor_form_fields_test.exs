defmodule HolterWeb.Components.Monitoring.MonitorFormFieldsTest do
  use HolterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import HolterWeb.Components.Monitoring.MonitorFormFields

  defp form(params \\ %{}) do
    Phoenix.Component.to_form(params, as: :monitor)
  end

  describe "monitor_form_technical/1" do
    test "renders URL input" do
      html = render_component(&monitor_form_technical/1, form: form())
      assert html =~ ~s(type="url")
    end

    test "renders method select" do
      html = render_component(&monitor_form_technical/1, form: form())
      assert html =~ "<select"
    end

    test "renders custom headers textarea" do
      html = render_component(&monitor_form_technical/1, form: form())
      assert html =~ "Custom Headers"
    end

    test "hides body field for GET method" do
      html = render_component(&monitor_form_technical/1, form: form(%{"method" => "get"}))
      refute html =~ "Request Body"
    end

    test "shows body field for POST method" do
      html = render_component(&monitor_form_technical/1, form: form(%{"method" => "post"}))
      assert html =~ "Request Body"
    end
  end

  describe "monitor_form_security/1" do
    test "renders keyword positive input" do
      html = render_component(&monitor_form_security/1, form: form())
      assert html =~ "Must Contain"
    end

    test "renders keyword negative input" do
      html = render_component(&monitor_form_security/1, form: form())
      assert html =~ "Must Not Contain"
    end

    test "renders SSL ignore checkbox" do
      html = render_component(&monitor_form_security/1, form: form())
      assert html =~ "Ignore SSL"
    end

    test "renders follow redirects checkbox" do
      html = render_component(&monitor_form_security/1, form: form())
      assert html =~ "Follow Redirects"
    end

    test "hides max_redirects when follow_redirects is false" do
      html =
        render_component(&monitor_form_security/1, form: form(%{"follow_redirects" => "false"}))

      refute html =~ "Max Redirects"
    end

    test "shows max_redirects when follow_redirects is true" do
      html =
        render_component(&monitor_form_security/1, form: form(%{"follow_redirects" => "true"}))

      assert html =~ "Max Redirects"
    end
  end

  describe "monitor_form_interval/1" do
    test "renders interval range slider" do
      html = render_component(&monitor_form_interval/1, form: form())
      assert html =~ ~s(type="range")
    end

    test "renders timeout input" do
      html = render_component(&monitor_form_interval/1, form: form())
      assert html =~ "Timeout"
    end

    test "does not render logical_state select when show_logical_state is false" do
      html = render_component(&monitor_form_interval/1, form: form(), show_logical_state: false)
      refute html =~ "Monitor State"
    end

    test "renders logical_state select when show_logical_state is true" do
      html = render_component(&monitor_form_interval/1, form: form(), show_logical_state: true)
      assert html =~ "Monitor State"
    end

    test "applies min_interval_seconds to range slider min attribute" do
      html = render_component(&monitor_form_interval/1, form: form(), min_interval_seconds: 300)
      assert html =~ ~s(min="300")
    end

    test "renders interval value in minutes" do
      html =
        render_component(&monitor_form_interval/1, form: form(%{"interval_seconds" => "120"}))

      assert html =~ "2 min"
    end

    test "allows a 24-hour interval as the slider maximum" do
      html = render_component(&monitor_form_interval/1, form: form())

      assert html =~ ~s(max="86400")
    end

    test "renders mixed hour-and-minute intervals using the compact label" do
      html =
        render_component(&monitor_form_interval/1, form: form(%{"interval_seconds" => "5400"}))

      assert html =~ "1 h 30 min"
    end

    test "renders 24-hour intervals as a clean hour label" do
      html =
        render_component(&monitor_form_interval/1, form: form(%{"interval_seconds" => "86400"}))

      assert html =~ "24 h"
    end
  end
end
