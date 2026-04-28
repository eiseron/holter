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

    test "shows email placeholder and email input type by default", %{
      conn: conn,
      workspace: workspace
    } do
      {:ok, _view, html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/notification-channels/new")

      assert html =~ ~s(placeholder="ops@example.com")
      assert html =~ ~s(type="email")
    end

    test "updates placeholder and input type when type changes to webhook", %{
      conn: conn,
      workspace: workspace
    } do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/notification-channels/new")

      html =
        view
        |> form("#notification-channel-form", notification_channel: %{type: "webhook"})
        |> render_change()

      assert html =~ ~s(placeholder="https://example.com/webhook")
      assert html =~ ~s(type="text")
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

      assert_redirect(view, "/delivery/workspaces/#{workspace.slug}/channels")
    end

    test "shows CC recipients section by default (email type)", %{
      conn: conn,
      workspace: workspace
    } do
      {:ok, _view, html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/notification-channels/new")

      assert html =~ "CC Recipients"
    end

    test "hides CC recipients section when type changes to webhook", %{
      conn: conn,
      workspace: workspace
    } do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/notification-channels/new")

      html =
        view
        |> form("#notification-channel-form", notification_channel: %{type: "webhook"})
        |> render_change()

      refute html =~ "CC Recipients"
    end

    test "does not add invalid email to CC list", %{conn: conn, workspace: workspace} do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/notification-channels/new")

      html =
        view
        |> element("input[name='cc_email']")
        |> render_keydown(%{"key" => "Enter", "value" => "notanemail"})

      refute html =~ "notanemail"
    end

    test "does not add duplicate email to CC list", %{conn: conn, workspace: workspace} do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/notification-channels/new")

      view
      |> element("input[name='cc_email']")
      |> render_keydown(%{"key" => "Enter", "value" => "cc@example.com"})

      html =
        view
        |> element("input[name='cc_email']")
        |> render_keydown(%{"key" => "Enter", "value" => "cc@example.com"})

      assert [_] = Regex.scan(~r/h-recipient-item/, html)
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

    test "sends a verification email to the primary target when an email channel is created",
         %{conn: conn, workspace: workspace} do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/notification-channels/new")

      view
      |> form("#notification-channel-form", notification_channel: %{type: "email"})
      |> render_change()

      view
      |> form("#notification-channel-form",
        notification_channel: %{
          name: "Ops",
          type: "email",
          target: "ops@example.com"
        }
      )
      |> render_submit()

      assert_email_sent(to: "ops@example.com")
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

    test "deletes channel and redirects after confirmation", %{conn: conn, workspace: workspace} do
      channel = channel_fixture(workspace.id)

      {:ok, view, html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      assert html =~ "Are you sure"
      assert html =~ ~r/id="delete-channel-modal"[^>]*hidden=""/

      view |> element("button[phx-click='delete_channel']") |> render_click()

      assert_redirect(view, "/delivery/workspaces/#{workspace.slug}/channels")
      assert {:error, :not_found} = Delivery.get_channel(channel.id)
    end

    test "does not delete channel when confirmation is not given", %{
      conn: conn,
      workspace: workspace
    } do
      channel = channel_fixture(workspace.id)

      {:ok, _view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      assert {:ok, _} = Delivery.get_channel(channel.id)
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

    test "renders the webhook signing section for webhook channels", %{
      conn: conn,
      workspace: workspace
    } do
      channel = channel_fixture(workspace.id)

      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      assert html =~ ~s(id="signing-heading")
    end

    test "shows the channel's signing_token inside the webhook signing section", %{
      conn: conn,
      workspace: workspace
    } do
      channel = channel_fixture(workspace.id)

      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      assert html =~ channel.webhook_channel.signing_token
    end

    test "does not render the webhook signing section for email channels", %{
      conn: conn,
      workspace: workspace
    } do
      channel = email_channel_fixture(workspace.id)

      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      refute html =~ ~s(id="signing-heading")
    end

    test "regenerate_secret event rotates the signing_token displayed in the page", %{
      conn: conn,
      workspace: workspace
    } do
      channel = channel_fixture(workspace.id)
      original = channel.webhook_channel.signing_token

      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      html = render_click(view, "regenerate_secret", %{})

      refute html =~ original
    end

    test "regenerate_secret event persists the new signing_token to the database", %{
      conn: conn,
      workspace: workspace
    } do
      channel = channel_fixture(workspace.id)
      original = channel.webhook_channel.signing_token

      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      render_click(view, "regenerate_secret", %{})

      reloaded =
        Holter.Repo.get_by!(Holter.Delivery.WebhookChannel, notification_channel_id: channel.id)

      assert reloaded.signing_token != original
    end

    test "renders the anti-phishing section for email channels", %{
      conn: conn,
      workspace: workspace
    } do
      channel = email_channel_fixture(workspace.id)

      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      assert html =~ ~s(id="phishing-heading")
    end

    test "shows the channel's anti_phishing_code inside the anti-phishing section", %{
      conn: conn,
      workspace: workspace
    } do
      channel = email_channel_fixture(workspace.id)

      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      assert html =~ channel.email_channel.anti_phishing_code
    end

    test "does not render the anti-phishing section for webhook channels", %{
      conn: conn,
      workspace: workspace
    } do
      channel = channel_fixture(workspace.id)

      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      refute html =~ ~s(id="phishing-heading")
    end

    test "regenerate_secret event rotates the anti_phishing_code displayed in the page", %{
      conn: conn,
      workspace: workspace
    } do
      channel = email_channel_fixture(workspace.id)
      original = channel.email_channel.anti_phishing_code

      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      html = render_click(view, "regenerate_secret", %{})

      refute html =~ original
    end

    test "regenerate_secret event persists the new anti_phishing_code to the database", %{
      conn: conn,
      workspace: workspace
    } do
      channel = email_channel_fixture(workspace.id)
      original = channel.email_channel.anti_phishing_code

      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      render_click(view, "regenerate_secret", %{})

      reloaded =
        Holter.Repo.get_by!(Holter.Delivery.EmailChannel, notification_channel_id: channel.id)

      assert reloaded.anti_phishing_code != original
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

    test "does not add invalid email to CC list", %{conn: conn, workspace: workspace} do
      channel = email_channel_fixture(workspace.id)

      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      html =
        view
        |> element("input[name='cc_email']")
        |> render_keydown(%{"key" => "Enter", "value" => "notanemail"})

      refute html =~ "notanemail"
    end

    test "does not add duplicate email to CC list", %{conn: conn, workspace: workspace} do
      channel = email_channel_fixture(workspace.id)

      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      view
      |> element("input[name='cc_email']")
      |> render_keydown(%{"key" => "Enter", "value" => "cc@example.com"})

      html =
        view
        |> element("input[name='cc_email']")
        |> render_keydown(%{"key" => "Enter", "value" => "cc@example.com"})

      assert [_] = Regex.scan(~r/h-recipient-item/, html)
    end
  end

  describe "Show — email channel verification" do
    defp verified_email_channel_fixture(workspace_id) do
      {:ok, channel} =
        Delivery.create_channel(%{
          workspace_id: workspace_id,
          name: "Ops Email",
          type: :email,
          target: "ops@example.com"
        })

      {:ok, with_token} = Delivery.send_email_channel_verification(channel)

      {:ok, verified} =
        Delivery.verify_email_channel(with_token.email_channel.verification_token)

      verified
    end

    test "renders the pending badge when the primary target is unverified", %{
      conn: conn,
      workspace: workspace
    } do
      channel = email_channel_fixture(workspace.id)

      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      assert html =~ ~s(id="email-verification-heading")
      assert html =~ "Pending verification"
      assert html =~ "Resend verification"
    end

    test "renders the verified badge and hides the resend button when the primary is verified",
         %{conn: conn, workspace: workspace} do
      channel = verified_email_channel_fixture(workspace.id)

      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      assert html =~ "Verified"
      refute html =~ "Resend verification"
    end

    test "does not render the verification section for webhook channels", %{
      conn: conn,
      workspace: workspace
    } do
      channel = channel_fixture(workspace.id)

      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      refute html =~ ~s(id="email-verification-heading")
    end

    test "resend_email_verification event ships an email and rotates the token", %{
      conn: conn,
      workspace: workspace
    } do
      channel = email_channel_fixture(workspace.id)
      original_token = channel.email_channel.verification_token

      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      render_click(view, "resend_email_verification", %{})

      assert_email_sent(to: "ops@example.com")

      reloaded =
        Holter.Repo.get_by!(Holter.Delivery.EmailChannel, notification_channel_id: channel.id)

      assert reloaded.verification_token != original_token
    end

    test "Send Test on an unverified email channel surfaces a clear error flash", %{
      conn: conn,
      workspace: workspace
    } do
      channel = email_channel_fixture(workspace.id)

      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      html = render_click(view, "test", %{})

      assert html =~ "no recipient on this channel is verified"
    end

    test "renders the Resend button next to a pending CC recipient", %{
      conn: conn,
      workspace: workspace
    } do
      channel = email_channel_fixture(workspace.id)
      Delivery.add_recipient(channel.id, "cc@example.com")

      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      assert html =~ ~s(phx-click="resend_recipient_verification")
    end

    test "does not render the Resend button next to a verified CC recipient", %{
      conn: conn,
      workspace: workspace
    } do
      channel = email_channel_fixture(workspace.id)
      {:ok, recipient} = Delivery.add_recipient(channel.id, "verified@example.com")
      Delivery.verify_recipient(recipient.token)

      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      refute html =~ ~s(phx-value-id="#{recipient.id}\" phx-disable-with)
      refute html =~ ~s(phx-click="resend_recipient_verification" phx-value-id="#{recipient.id}")
    end

    test "resend_recipient_verification event ships a fresh email", %{
      conn: conn,
      workspace: workspace
    } do
      channel = email_channel_fixture(workspace.id)
      {:ok, recipient} = Delivery.add_recipient(channel.id, "cc@example.com")

      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      render_click(view, "resend_recipient_verification", %{"id" => recipient.id})

      assert_email_sent(to: "cc@example.com")
    end

    test "resend_recipient_verification rotates the recipient's token", %{
      conn: conn,
      workspace: workspace
    } do
      channel = email_channel_fixture(workspace.id)
      {:ok, recipient} = Delivery.add_recipient(channel.id, "rot@example.com")
      original_token = recipient.token

      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      render_click(view, "resend_recipient_verification", %{"id" => recipient.id})

      [reloaded] = Delivery.list_recipients(channel.id)
      assert reloaded.token != original_token
    end
  end

  describe "Show — full email channel update flow" do
    test "updates email channel with CC recipients and monitors", %{
      conn: conn,
      workspace: workspace
    } do
      monitor1 = monitor_fixture(%{workspace_id: workspace.id})
      monitor2 = monitor_fixture(%{workspace_id: workspace.id})

      channel = email_channel_fixture(workspace.id)

      {:ok, view, html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      assert html =~ channel.name
      assert html =~ channel.target
      assert html =~ "The primary email address that will receive alerts."
      assert html =~ "CC Recipients"
      assert html =~ monitor1.url
      assert html =~ monitor2.url

      html =
        view
        |> element("input[name='cc_email']")
        |> render_keydown(%{"key" => "Enter", "value" => "alice@example.com"})

      assert html =~ "alice@example.com"
      assert html =~ "Pending"

      html =
        view
        |> element("input[name='cc_email']")
        |> render_keydown(%{"key" => "Enter", "value" => "bob@example.com"})

      assert html =~ "alice@example.com"
      assert html =~ "bob@example.com"

      view
      |> form("#notification-channel-form",
        notification_channel: %{
          name: "Updated Alerts",
          target: "new@example.com"
        }
      )
      |> render_submit(%{"monitor_ids" => [monitor1.id, monitor2.id]})

      assert render(view) =~ "Channel updated successfully"

      updated = Delivery.get_channel!(channel.id)
      assert updated.name == "Updated Alerts"
      assert updated.target == "new@example.com"

      assert monitor1.id in Delivery.list_monitor_ids_for_channel(channel.id)
      assert monitor2.id in Delivery.list_monitor_ids_for_channel(channel.id)

      recipients = Delivery.list_recipients(channel.id)
      assert length(recipients) == 2
      recipient_emails = Enum.map(recipients, & &1.email) |> MapSet.new()
      assert MapSet.member?(recipient_emails, "alice@example.com")
      assert MapSet.member?(recipient_emails, "bob@example.com")

      assert_email_sent(to: "alice@example.com")
      assert_email_sent(to: "bob@example.com")
    end
  end

  describe "New — full email channel creation flow" do
    test "creates email channel with CC recipients and monitors", %{
      conn: conn,
      workspace: workspace
    } do
      monitor1 = monitor_fixture(%{workspace_id: workspace.id})
      monitor2 = monitor_fixture(%{workspace_id: workspace.id})

      {:ok, view, html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/notification-channels/new")

      assert html =~ ~s(name="notification_channel[name]")
      assert html =~ "CC Recipients"
      assert html =~ ~s(value="")
      assert html =~ "The primary email address that will receive alerts."
      assert html =~ monitor1.url
      assert html =~ monitor2.url

      view
      |> form("#notification-channel-form",
        notification_channel: %{
          name: "Production Alerts",
          type: "email",
          target: "ops@example.com"
        }
      )
      |> render_change()

      html =
        view
        |> element("input[name='cc_email']")
        |> render_keydown(%{"key" => "Enter", "value" => "alice@example.com"})

      assert html =~ "alice@example.com"
      assert html =~ "Pending verification"
      assert Delivery.list_channels(workspace.id) == []

      html =
        view
        |> element("input[name='cc_email']")
        |> render_keydown(%{"key" => "Enter", "value" => "bob@example.com"})

      assert html =~ "alice@example.com"
      assert html =~ "bob@example.com"
      assert html =~ ~s(value="Production Alerts")
      assert html =~ ~s(value="ops@example.com")
      assert html =~ "Pending verification"
      assert Delivery.list_channels(workspace.id) == []

      view
      |> form("#notification-channel-form",
        notification_channel: %{
          name: "Production Alerts",
          type: "email",
          target: "ops@example.com"
        }
      )
      |> render_submit(%{"monitor_ids" => [monitor1.id, monitor2.id]})

      assert_redirect(view, "/delivery/workspaces/#{workspace.slug}/channels")

      channel = Delivery.list_channels(workspace.id) |> List.last()
      assert channel.name == "Production Alerts"
      assert channel.type == :email
      assert channel.target == "ops@example.com"

      assert monitor1.id in Delivery.list_monitor_ids_for_channel(channel.id)
      assert monitor2.id in Delivery.list_monitor_ids_for_channel(channel.id)

      recipients = Delivery.list_recipients(channel.id)
      assert length(recipients) == 2
      recipient_emails = Enum.map(recipients, & &1.email) |> MapSet.new()
      assert MapSet.member?(recipient_emails, "alice@example.com")
      assert MapSet.member?(recipient_emails, "bob@example.com")

      assert_email_sent(to: "alice@example.com")
      assert_email_sent(to: "bob@example.com")
    end
  end
end
