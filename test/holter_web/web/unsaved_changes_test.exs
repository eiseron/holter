defmodule HolterWeb.Web.UnsavedChangesTest do
  use HolterWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Holter.Monitoring

  defp form_attrs(html, form_id) do
    html
    |> Floki.parse_document!()
    |> Floki.find("form##{form_id}")
    |> case do
      [{"form", attrs, _children}] -> Map.new(attrs)
      _ -> nil
    end
  end

  describe "root layout exposes the unsaved-changes confirm message globally" do
    setup do
      monitor = monitor_fixture(%{url: "https://example.local"})
      workspace = Monitoring.get_workspace!(monitor.workspace_id)
      %{monitor: monitor, workspace: workspace}
    end

    test "head exposes app-config JSON with the translated unsaved_confirm string", %{
      conn: conn,
      monitor: monitor
    } do
      {:ok, _view, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      [{"meta", attrs, _}] =
        html
        |> Floki.parse_document!()
        |> Floki.find(~s|meta#app-config|)

      data_config = Enum.find_value(attrs, fn {k, v} -> if k == "data-config", do: v end)
      assert Jason.decode!(data_config)["i18n"]["unsaved_confirm"] =~ "unsaved changes"
    end
  end

  describe "forms with phx-submit are automatically covered by the unsaved-changes guard" do
    setup do
      monitor = monitor_fixture(%{url: "https://example.local"})
      %{monitor: monitor}
    end

    test "monitor edit form has phx-submit and does not opt out", %{
      conn: conn,
      monitor: monitor
    } do
      {:ok, _view, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      attrs = form_attrs(html, "monitor-form")

      assert is_map(attrs)
      assert Map.has_key?(attrs, "phx-submit")
      refute Map.has_key?(attrs, "data-no-warn")
    end

    test "logs filter form is excluded because it has no phx-submit", %{
      conn: conn,
      monitor: monitor
    } do
      {:ok, _view, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/logs")

      filter_form =
        html
        |> Floki.parse_document!()
        |> Floki.find(~s|form[phx-change="filter_updated"]|)

      assert filter_form != []
      [{"form", attrs, _}] = filter_form
      refute Map.new(attrs) |> Map.has_key?("phx-submit")
    end
  end

  describe "forms outside the dirty-editing flow opt out via data-no-warn" do
    @tag :guest
    test "forgot-password form opts out of unsaved-changes tracking", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/identity/forgot-password")

      attrs = form_attrs(html, "forgot-password-form")

      assert is_map(attrs)
      assert Map.has_key?(attrs, "phx-submit")
      assert Map.has_key?(attrs, "data-no-warn")
    end
  end

  describe "server-side draft state declares dirty via phx:form-dirty" do
    test "adding a draft recipient on the new email channel page marks the form dirty",
         %{conn: conn, current_workspace: workspace} do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/email-channels/new")

      view
      |> form("#add-recipient-form", %{"recipient" => %{"email" => "draft@example.test"}})
      |> render_submit()

      assert_push_event(view, "form-dirty", %{form: "email-channel-form", dirty: true})
    end

    test "removing the last draft recipient clears the dirty flag back to clean",
         %{conn: conn, current_workspace: workspace} do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/email-channels/new")

      view
      |> form("#add-recipient-form", %{"recipient" => %{"email" => "draft@example.test"}})
      |> render_submit()

      assert_push_event(view, "form-dirty", %{form: "email-channel-form", dirty: true})

      view
      |> element(
        ~s|button[phx-click="remove_pending_recipient"][phx-value-email="draft@example.test"]|
      )
      |> render_click()

      assert_push_event(view, "form-dirty", %{form: "email-channel-form", dirty: false})
    end
  end
end
