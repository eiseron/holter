defmodule HolterWeb.Web.Delivery.EmailChannelLive.ShowTest do
  use HolterWeb.ConnCase
  use Oban.Testing, repo: Holter.Repo

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias Holter.Delivery.EmailChannels

  setup do
    workspace = workspace_fixture()

    {:ok, channel} =
      EmailChannels.create(%{workspace_id: workspace.id, name: "Ops Email"})

    %{workspace: workspace, channel: channel}
  end

  defp add_verified_recipient(channel, email \\ "ops@example.com") do
    {:ok, recipient} = EmailChannels.add_recipient(channel.id, email)
    {:ok, _} = EmailChannels.verify_recipient(recipient.token)
    :ok
  end

  describe "mount" do
    test "renders the channel name in the page header",
         %{conn: conn, channel: channel} do
      {:ok, _view, html} = live(conn, ~p"/delivery/email-channels/#{channel.id}")

      assert html =~ channel.name
    end

    test "renders the edit form", %{conn: conn, channel: channel} do
      {:ok, _view, html} = live(conn, ~p"/delivery/email-channels/#{channel.id}")

      assert html =~ "email-channel-form"
    end

    test "renders the View Logs link",
         %{conn: conn, channel: channel} do
      {:ok, _view, html} = live(conn, ~p"/delivery/email-channels/#{channel.id}")

      assert html =~ "/delivery/email-channels/#{channel.id}/logs"
    end
  end

  describe "save event" do
    test "updates the channel name on valid submit",
         %{conn: conn, channel: channel} do
      {:ok, view, _html} = live(conn, ~p"/delivery/email-channels/#{channel.id}")

      view
      |> form("#email-channel-form", email_channel: %{name: "Renamed"})
      |> render_submit()

      assert EmailChannels.get!(channel.id).name == "Renamed"
    end
  end

  describe "test dispatch" do
    test "fails with a flash when the channel has no verified recipients",
         %{conn: conn, channel: channel} do
      {:ok, view, _html} = live(conn, ~p"/delivery/email-channels/#{channel.id}")

      html = view |> element("button[phx-click='test']") |> render_click()

      assert html =~ "no verified recipients"
    end

    test "enqueues an email test job once at least one recipient is verified",
         %{conn: conn, channel: channel} do
      :ok = add_verified_recipient(channel)

      {:ok, view, _html} = live(conn, ~p"/delivery/email-channels/#{channel.id}")

      view |> element("button[phx-click='test']") |> render_click()

      assert_enqueued(
        worker: Holter.Delivery.Workers.EmailDispatcher,
        args: %{"test" => true, "email_channel_id" => channel.id}
      )
    end
  end

  describe "recipients" do
    test "renders the recipients section",
         %{conn: conn, channel: channel} do
      {:ok, _view, html} = live(conn, ~p"/delivery/email-channels/#{channel.id}")

      assert html =~ "Recipients"
      assert html =~ "Add Recipient"
    end

    test "the recipient form and the channel save form are siblings, not nested",
         %{conn: conn, channel: channel} do
      {:ok, _view, html} = live(conn, ~p"/delivery/email-channels/#{channel.id}")

      doc = Floki.parse_document!(html)

      nested_recipient_inside_save =
        Floki.find(doc, ~s|form#email-channel-form form#add-recipient-form|)

      assert nested_recipient_inside_save == []
    end

    test "the recipient input renders an empty value= so LiveView form recovery can clear it",
         %{conn: conn, channel: channel} do
      {:ok, _view, html} = live(conn, ~p"/delivery/email-channels/#{channel.id}")

      input_value =
        html
        |> Floki.parse_document!()
        |> Floki.find(~s|form#add-recipient-form input[name="recipient[email]"]|)
        |> Floki.attribute("value")

      assert input_value == [""]
    end

    test "submitting the recipient form stages it without persisting or sending email",
         %{conn: conn, channel: channel} do
      {:ok, view, _html} = live(conn, ~p"/delivery/email-channels/#{channel.id}")

      html =
        view
        |> form("#add-recipient-form", %{"recipient" => %{"email" => "alice@example.com"}})
        |> render_submit()

      assert html =~ "alice@example.com"
      assert html =~ "Draft"
      assert EmailChannels.list_recipients(channel.id) == []
      refute_email_sent()
    end

    test "the staging submit pushes recipient-input-clear so the browser can reset the field",
         %{conn: conn, channel: channel} do
      {:ok, view, _html} = live(conn, ~p"/delivery/email-channels/#{channel.id}")

      view
      |> form("#add-recipient-form", %{"recipient" => %{"email" => "alice@example.com"}})
      |> render_submit()

      assert_push_event(view, "recipient-input-clear", %{})
    end

    test "marking a saved recipient for removal renders it struck-through with Restore",
         %{conn: conn, channel: channel} do
      {:ok, recipient} = EmailChannels.add_recipient(channel.id, "alice@example.com")

      {:ok, view, _html} = live(conn, ~p"/delivery/email-channels/#{channel.id}")

      html = render_click(view, "mark_recipient_for_removal", %{"id" => recipient.id})

      assert html =~ "Will be removed"
      assert html =~ "Restore"
      assert html =~ "alice@example.com"
      assert EmailChannels.list_recipients(channel.id) != []
    end

    test "restoring a recipient marked for removal returns it to the saved state",
         %{conn: conn, channel: channel} do
      {:ok, recipient} = EmailChannels.add_recipient(channel.id, "alice@example.com")

      {:ok, view, _html} = live(conn, ~p"/delivery/email-channels/#{channel.id}")

      render_click(view, "mark_recipient_for_removal", %{"id" => recipient.id})
      html = render_click(view, "restore_recipient", %{"id" => recipient.id})

      refute html =~ "Will be removed"
      refute html =~ "Restore"
    end

    test "cancelling a pending addition removes it from the staged list",
         %{conn: conn, channel: channel} do
      {:ok, view, _html} = live(conn, ~p"/delivery/email-channels/#{channel.id}")

      view
      |> form("#add-recipient-form", %{"recipient" => %{"email" => "alice@example.com"}})
      |> render_submit()

      html = render_click(view, "cancel_pending_recipient", %{"email" => "alice@example.com"})

      refute html =~ "alice@example.com"
    end

    test "save applies pending additions and removals atomically and sends verification emails",
         %{conn: conn, channel: channel} do
      {:ok, kept} = EmailChannels.add_recipient(channel.id, "kept@example.com")
      {:ok, removed} = EmailChannels.add_recipient(channel.id, "removed@example.com")

      {:ok, view, _html} = live(conn, ~p"/delivery/email-channels/#{channel.id}")

      view
      |> form("#add-recipient-form", %{"recipient" => %{"email" => "alice@example.com"}})
      |> render_submit()

      render_click(view, "mark_recipient_for_removal", %{"id" => removed.id})

      view
      |> form("#email-channel-form", email_channel: %{name: channel.name})
      |> render_submit()

      remaining_emails =
        channel.id |> EmailChannels.list_recipients() |> Enum.map(& &1.email) |> Enum.sort()

      assert remaining_emails == ["alice@example.com", "kept@example.com"]
      assert_email_sent(to: "alice@example.com")
      _ = kept
    end
  end

  describe "regenerate anti-phishing code" do
    test "rotates the code on confirmation",
         %{conn: conn, channel: channel} do
      original = channel.anti_phishing_code

      {:ok, view, _html} = live(conn, ~p"/delivery/email-channels/#{channel.id}")

      render_click(view, "regenerate_secret", %{})

      assert EmailChannels.get!(channel.id).anti_phishing_code != original
    end
  end

  describe "delete" do
    test "deletes the channel and redirects to the workspace channels list",
         %{conn: conn, workspace: workspace, channel: channel} do
      {:ok, view, _html} = live(conn, ~p"/delivery/email-channels/#{channel.id}")

      view |> element("button[phx-click='delete_channel']") |> render_click()

      assert_redirect(view, "/delivery/workspaces/#{workspace.slug}/channels")
      assert {:error, :not_found} = EmailChannels.get(channel.id)
    end
  end
end
