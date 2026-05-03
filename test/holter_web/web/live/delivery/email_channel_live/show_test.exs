defmodule HolterWeb.Web.Delivery.EmailChannelLive.ShowTest do
  use HolterWeb.ConnCase
  use Oban.Testing, repo: Holter.Repo

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias Holter.Delivery.EmailChannels

  setup do
    workspace = workspace_fixture()

    {:ok, channel} =
      EmailChannels.create(%{
        workspace_id: workspace.id,
        name: "Ops Email",
        address: "ops@example.com"
      })

    %{workspace: workspace, channel: channel}
  end

  defp mark_verified(channel) do
    channel
    |> Ecto.Changeset.change(verified_at: DateTime.utc_now() |> DateTime.truncate(:second))
    |> Holter.Repo.update!()
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

    test "renders the resend verification button when the address is unverified",
         %{conn: conn, channel: channel} do
      {:ok, _view, html} = live(conn, ~p"/delivery/email-channels/#{channel.id}")

      assert html =~ "Resend verification"
    end

    test "hides the resend verification section once the address is verified",
         %{conn: conn, channel: channel} do
      mark_verified(channel)

      {:ok, _view, html} = live(conn, ~p"/delivery/email-channels/#{channel.id}")

      refute html =~ "Resend verification"
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
    test "fails with a flash when the address has no verified recipients",
         %{conn: conn, channel: channel} do
      {:ok, view, _html} = live(conn, ~p"/delivery/email-channels/#{channel.id}")

      html = view |> element("button[phx-click='test']") |> render_click()

      assert html =~ "no recipient on this channel is verified"
    end

    test "enqueues an email test job once the address is verified",
         %{conn: conn, channel: channel} do
      mark_verified(channel)

      {:ok, view, _html} = live(conn, ~p"/delivery/email-channels/#{channel.id}")

      view |> element("button[phx-click='test']") |> render_click()

      assert_enqueued(
        worker: Holter.Delivery.Workers.EmailDispatcher,
        args: %{"test" => true, "email_channel_id" => channel.id}
      )
    end
  end

  describe "CC recipients" do
    test "renders the recipients section",
         %{conn: conn, channel: channel} do
      {:ok, _view, html} = live(conn, ~p"/delivery/email-channels/#{channel.id}")

      assert html =~ "CC Recipients"
    end

    test "adding a recipient sends a verification email and lists it",
         %{conn: conn, channel: channel} do
      {:ok, view, _html} = live(conn, ~p"/delivery/email-channels/#{channel.id}")

      html = render_click(view, "add_recipient", %{"email" => "alice@example.com"})

      assert html =~ "alice@example.com"
      assert_email_sent(to: "alice@example.com")
    end

    test "removing a recipient drops it from the list",
         %{conn: conn, channel: channel} do
      {:ok, recipient} = EmailChannels.add_recipient(channel.id, "alice@example.com")

      {:ok, view, _html} = live(conn, ~p"/delivery/email-channels/#{channel.id}")

      html = render_click(view, "remove_recipient", %{"id" => recipient.id})

      refute html =~ "alice@example.com"
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

  describe "resend channel verification" do
    test "sends a verification email to the primary address",
         %{conn: conn, channel: channel} do
      {:ok, view, _html} = live(conn, ~p"/delivery/email-channels/#{channel.id}")

      render_click(view, "resend_email_verification", %{})

      assert_email_sent(to: channel.address)
    end
  end
end
