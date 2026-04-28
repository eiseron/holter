defmodule HolterWeb.Web.Delivery.EmailChannelLive.VerifyTest do
  use HolterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Holter.Delivery
  alias Holter.Delivery.EmailChannel
  alias Holter.Repo

  setup do
    ws = workspace_fixture()

    {:ok, channel} =
      Delivery.create_channel(%{
        workspace_id: ws.id,
        name: "Ops Email",
        type: :email,
        target: "ops@example.com"
      })

    {:ok, with_token} = Delivery.send_email_channel_verification(channel)
    %{channel: with_token, token: with_token.email_channel.verification_token}
  end

  describe "valid token" do
    test "renders verified heading", %{conn: conn, token: token} do
      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/email-channels/verify/#{token}")

      assert html =~ "Email channel verified"
    end

    test "marks the email_channels row as verified in the database", %{
      conn: conn,
      channel: channel,
      token: token
    } do
      {:ok, _view, _html} =
        live(conn, ~p"/delivery/notification-channels/email-channels/verify/#{token}")

      reloaded = Repo.get_by!(EmailChannel, notification_channel_id: channel.id)
      assert %DateTime{} = reloaded.verified_at
    end

    test "renders a link back to the channel show page", %{
      conn: conn,
      channel: channel,
      token: token
    } do
      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/email-channels/verify/#{token}")

      assert html =~ "/delivery/notification-channels/#{channel.id}"
    end
  end

  describe "expired token" do
    test "renders expired heading and leaves the row unverified", %{
      conn: conn,
      channel: channel,
      token: token
    } do
      past = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      channel.email_channel
      |> Ecto.Changeset.change(verification_token_expires_at: past)
      |> Repo.update!()

      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/email-channels/verify/#{token}")

      assert html =~ "Link expired"
      reloaded = Repo.get_by!(EmailChannel, notification_channel_id: channel.id)
      assert is_nil(reloaded.verified_at)
    end
  end

  describe "unknown token" do
    test "renders not-found heading", %{conn: conn} do
      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/email-channels/verify/unknown-token")

      assert html =~ "Link not found"
    end
  end
end
