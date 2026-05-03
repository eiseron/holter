defmodule HolterWeb.Web.Delivery.EmailChannelRecipientLive.VerifyTest do
  use HolterWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Holter.Delivery.{EmailChannelRecipient, EmailChannels}

  setup do
    workspace = workspace_fixture()

    {:ok, channel} =
      EmailChannels.create(%{
        workspace_id: workspace.id,
        name: "Alerts",
        address: "primary@example.com"
      })

    %{channel: channel}
  end

  describe "Verify" do
    test "shows verified status for a valid token", %{conn: conn, channel: channel} do
      {:ok, recipient} = EmailChannels.add_recipient(channel.id, "alice@example.com")

      {:ok, _view, html} =
        live(conn, ~p"/delivery/email-channels/recipients/verify/#{recipient.token}")

      assert html =~ "Email verified"
      assert html =~ "Back to channel settings"
    end

    test "shows expired status for an expired token", %{conn: conn, channel: channel} do
      {:ok, recipient} = EmailChannels.add_recipient(channel.id, "bob@example.com")

      past =
        NaiveDateTime.add(NaiveDateTime.utc_now(), -1, :second)
        |> NaiveDateTime.truncate(:second)

      recipient
      |> EmailChannelRecipient.changeset(%{token_expires_at: past})
      |> Holter.Repo.update!()

      {:ok, _view, html} =
        live(conn, ~p"/delivery/email-channels/recipients/verify/#{recipient.token}")

      assert html =~ "Link expired"
    end

    test "shows not found status for an unknown token", %{conn: conn} do
      {:ok, _view, html} =
        live(conn, ~p"/delivery/email-channels/recipients/verify/unknowntoken123")

      assert html =~ "Link not found"
    end
  end
end
