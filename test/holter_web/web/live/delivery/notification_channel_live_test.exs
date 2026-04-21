defmodule HolterWeb.Web.Delivery.NotificationChannelLiveTest do
  use HolterWeb.ConnCase
  use Oban.Testing, repo: Holter.Repo

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias Holter.Delivery

  setup do
    workspace = workspace_fixture()
    %{workspace: workspace}
  end

  defp channel_fixture(workspace_id, attrs \\ %{}) do
    {:ok, channel} =
      Delivery.create_channel(
        Map.merge(
          %{
            workspace_id: workspace_id,
            name: "Test Hook",
            type: :webhook,
            target: "https://example.com/hook"
          },
          attrs
        )
      )

    channel
  end

  describe "New" do
    test "renders creation form", %{conn: conn, workspace: workspace} do
      {:ok, _view, html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/notification-channels/new")

      assert html =~ "New Notification Channel"
      assert html =~ "notification-channel-form"
    end

    test "validates required fields on change", %{conn: conn, workspace: workspace} do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/notification-channels/new")

      html =
        view
        |> form("#notification-channel-form", notification_channel: %{name: ""})
        |> render_change()

      assert html =~ "notification-channel-form"
    end

    test "shows URL placeholder and url input type for webhook type by default", %{
      conn: conn,
      workspace: workspace
    } do
      {:ok, _view, html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/notification-channels/new")

      assert html =~ ~s(placeholder="https://example.com/webhook")
      assert html =~ ~s(type="text")
    end

    test "updates placeholder and input type when type changes to email", %{
      conn: conn,
      workspace: workspace
    } do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/notification-channels/new")

      html =
        view
        |> form("#notification-channel-form", notification_channel: %{type: "email"})
        |> render_change()

      assert html =~ ~s(placeholder="ops@example.com")
      assert html =~ ~s(type="email")
    end

    test "creates channel and redirects to workspace channels on valid submit", %{
      conn: conn,
      workspace: workspace
    } do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/notification-channels/new")

      view
      |> form("#notification-channel-form",
        notification_channel: %{
          name: "My Hook",
          type: "webhook",
          target: "https://hooks.example.com/notify"
        }
      )
      |> render_submit()

      assert_redirect(view, "/workspaces/#{workspace.slug}/channels")
    end

    test "shows CC recipients section when type is email", %{conn: conn, workspace: workspace} do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/notification-channels/new")

      html =
        view
        |> form("#notification-channel-form", notification_channel: %{type: "email"})
        |> render_change()

      assert html =~ "CC Recipients"
    end

    test "does not show CC recipients section for webhook type", %{
      conn: conn,
      workspace: workspace
    } do
      {:ok, _view, html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/notification-channels/new")

      refute html =~ "CC Recipients"
    end

    test "adds pending CC email to list before creation", %{conn: conn, workspace: workspace} do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/notification-channels/new")

      view
      |> form("#notification-channel-form", notification_channel: %{type: "email"})
      |> render_change()

      html = render_click(view, "add_pending_cc", %{"email" => "cc@example.com"})

      assert html =~ "cc@example.com"
      assert html =~ "Pending verification"
    end

    test "sends verification email to pending CC recipients on channel creation", %{
      conn: conn,
      workspace: workspace
    } do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/notification-channels/new")

      view
      |> form("#notification-channel-form", notification_channel: %{type: "email"})
      |> render_change()

      render_click(view, "add_pending_cc", %{"email" => "cc@example.com"})

      view
      |> form("#notification-channel-form",
        notification_channel: %{
          name: "Ops",
          type: "email",
          target: "ops@example.com"
        }
      )
      |> render_submit()

      assert_email_sent(to: "cc@example.com")
    end

    test "links selected monitors on channel creation", %{conn: conn, workspace: workspace} do
      monitor = monitor_fixture(%{workspace_id: workspace.id})

      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/notification-channels/new")

      view
      |> form("#notification-channel-form",
        notification_channel: %{
          name: "My Hook",
          type: "webhook",
          target: "https://hooks.example.com/notify"
        }
      )
      |> render_submit(%{"monitor_ids" => [monitor.id]})

      channel = Delivery.list_channels(workspace.id) |> List.last()
      assert monitor.id in Delivery.list_monitor_ids_for_channel(channel.id)
    end
  end

  describe "Show" do
    test "renders channel edit form", %{conn: conn, workspace: workspace} do
      channel = channel_fixture(workspace.id)

      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      assert html =~ channel.name
      assert html =~ "notification-channel-form"
    end

    test "updates channel name on valid submit", %{conn: conn, workspace: workspace} do
      channel = channel_fixture(workspace.id)

      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      view
      |> form("#notification-channel-form", notification_channel: %{name: "Renamed"})
      |> render_submit()

      assert render(view) =~ "Channel updated successfully"
      assert Delivery.get_channel!(channel.id).name == "Renamed"
    end

    test "enqueues test notification on test event", %{conn: conn, workspace: workspace} do
      channel = channel_fixture(workspace.id)

      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      view
      |> element("button[phx-click='test']")
      |> render_click()

      assert_enqueued(
        worker: Holter.Delivery.Workers.WebhookDispatcher,
        args: %{"test" => true, "channel_id" => channel.id}
      )
    end

    test "links monitors to channel on save", %{conn: conn, workspace: workspace} do
      channel = channel_fixture(workspace.id)
      monitor = monitor_fixture(%{workspace_id: workspace.id})

      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      view
      |> form("#notification-channel-form", notification_channel: %{name: channel.name})
      |> render_submit(%{"monitor_ids" => [monitor.id]})

      assert monitor.id in Delivery.list_monitor_ids_for_channel(channel.id)
    end

    test "unlinks monitors from channel when unchecked on save", %{
      conn: conn,
      workspace: workspace
    } do
      channel = channel_fixture(workspace.id)
      monitor = monitor_fixture(%{workspace_id: workspace.id})
      Delivery.link_monitor(monitor.id, channel.id)

      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      view
      |> form("#notification-channel-form", notification_channel: %{name: channel.name})
      |> render_submit(%{"monitor_ids" => []})

      refute monitor.id in Delivery.list_monitor_ids_for_channel(channel.id)
    end

    test "renders linked monitors as checked checkboxes", %{conn: conn, workspace: workspace} do
      channel = channel_fixture(workspace.id)
      monitor = monitor_fixture(%{workspace_id: workspace.id})
      Delivery.link_monitor(monitor.id, channel.id)

      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      assert html =~ ~s(value="#{monitor.id}" checked)
    end

    test "renders monitor URL in the monitor select", %{conn: conn, workspace: workspace} do
      channel = channel_fixture(workspace.id)
      monitor = monitor_fixture(%{workspace_id: workspace.id})

      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      assert html =~ monitor.url
    end
  end

  describe "Show — CC recipients (email channel)" do
    defp email_channel_fixture(workspace_id) do
      {:ok, channel} =
        Delivery.create_channel(%{
          workspace_id: workspace_id,
          name: "Ops Email",
          type: :email,
          target: "ops@example.com"
        })

      channel
    end

    test "renders CC recipients section for email channels", %{conn: conn, workspace: workspace} do
      channel = email_channel_fixture(workspace.id)

      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      assert html =~ "CC Recipients"
    end

    test "does not render CC recipients section for webhook channels", %{
      conn: conn,
      workspace: workspace
    } do
      channel = channel_fixture(workspace.id)

      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      refute html =~ "CC Recipients"
    end

    test "adds recipient and shows pending badge after add_recipient event", %{
      conn: conn,
      workspace: workspace
    } do
      channel = email_channel_fixture(workspace.id)

      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      html = render_click(view, "add_recipient", %{"email" => "cc@example.com"})

      assert html =~ "cc@example.com"
      assert html =~ "Pending"
    end

    test "sends verification email when recipient is added", %{
      conn: conn,
      workspace: workspace
    } do
      channel = email_channel_fixture(workspace.id)

      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      render_click(view, "add_recipient", %{"email" => "cc@example.com"})

      assert_email_sent(to: "cc@example.com")
    end

    test "shows error flash when adding duplicate email", %{conn: conn, workspace: workspace} do
      channel = email_channel_fixture(workspace.id)
      {:ok, _recipient} = Delivery.add_recipient(channel.id, "cc@example.com")

      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      html = render_click(view, "add_recipient", %{"email" => "cc@example.com"})

      assert html =~ "has already been added to this channel"
    end

    test "removes recipient on remove_recipient event", %{conn: conn, workspace: workspace} do
      channel = email_channel_fixture(workspace.id)
      {:ok, recipient} = Delivery.add_recipient(channel.id, "remove@example.com")

      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      html =
        view
        |> element("button[phx-click='remove_recipient'][phx-value-id='#{recipient.id}']")
        |> render_click()

      refute html =~ "remove@example.com"
    end

    test "shows verified badge for verified recipient", %{conn: conn, workspace: workspace} do
      channel = email_channel_fixture(workspace.id)
      {:ok, recipient} = Delivery.add_recipient(channel.id, "verified@example.com")
      Delivery.verify_recipient(recipient.token)

      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      assert html =~ "verified@example.com"
      assert html =~ "Verified"
    end
  end
end
