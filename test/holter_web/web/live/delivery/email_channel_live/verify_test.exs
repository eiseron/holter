defmodule HolterWeb.Web.Delivery.EmailChannelLive.VerifyTest do
  use HolterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Holter.Delivery.{EmailChannel, EmailChannels}
  alias Holter.Repo

  setup do
    ws = workspace_fixture()

    {:ok, channel} =
      EmailChannels.create(%{
        workspace_id: ws.id,
        name: "Ops Email",
        address: "ops@example.com"
      })

    {:ok, with_token} = EmailChannels.send_verification(channel)
    %{channel: with_token, token: with_token.verification_token}
  end

  describe "valid token" do
    test "renders verified heading", %{conn: conn, token: token} do
      {:ok, _view, html} =
        live(conn, ~p"/delivery/email-channels/verify/#{token}")

      assert html =~ "Email channel verified"
    end

    test "marks the email_channels row as verified in the database", %{
      conn: conn,
      channel: channel,
      token: token
    } do
      {:ok, _view, _html} =
        live(conn, ~p"/delivery/email-channels/verify/#{token}")

      reloaded = Repo.get!(EmailChannel, channel.id)
      assert %DateTime{} = reloaded.verified_at
    end

    test "renders a link back to the channel show page", %{
      conn: conn,
      channel: channel,
      token: token
    } do
      {:ok, _view, html} =
        live(conn, ~p"/delivery/email-channels/verify/#{token}")

      assert html =~ "/delivery/email-channels/#{channel.id}"
    end
  end

  describe "expired token" do
    test "renders expired heading and leaves the row unverified", %{
      conn: conn,
      channel: channel,
      token: token
    } do
      past = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      channel
      |> Ecto.Changeset.change(verification_token_expires_at: past)
      |> Repo.update!()

      {:ok, _view, html} =
        live(conn, ~p"/delivery/email-channels/verify/#{token}")

      assert html =~ "Link expired"
      reloaded = Repo.get!(EmailChannel, channel.id)
      assert is_nil(reloaded.verified_at)
    end
  end

  describe "unknown token" do
    test "renders not-found heading", %{conn: conn} do
      {:ok, _view, html} =
        live(conn, ~p"/delivery/email-channels/verify/unknown-token")

      assert html =~ "Link not found"
    end
  end
end
