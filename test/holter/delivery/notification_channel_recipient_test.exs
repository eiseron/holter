defmodule Holter.Delivery.NotificationChannelRecipientTest do
  use Holter.DataCase, async: true

  alias Holter.Delivery
  alias Holter.Delivery.NotificationChannelRecipient

  setup do
    workspace = workspace_fixture()

    {:ok, channel} =
      Delivery.create_channel(%{
        workspace_id: workspace.id,
        name: "Email Channel",
        type: :email,
        target: "primary@example.com"
      })

    %{channel: channel}
  end

  describe "NotificationChannelRecipient.changeset/2" do
    test "valid with required fields", %{channel: channel} do
      changeset =
        NotificationChannelRecipient.changeset(%NotificationChannelRecipient{}, %{
          notification_channel_id: channel.id,
          email: "alice@example.com"
        })

      assert changeset.valid?
    end

    test "invalid without email", %{channel: channel} do
      changeset =
        NotificationChannelRecipient.changeset(%NotificationChannelRecipient{}, %{
          notification_channel_id: channel.id
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).email
    end

    test "invalid with bad email format", %{channel: channel} do
      changeset =
        NotificationChannelRecipient.changeset(%NotificationChannelRecipient{}, %{
          notification_channel_id: channel.id,
          email: "not-an-email"
        })

      refute changeset.valid?
      assert "has invalid format" in errors_on(changeset).email
    end

    test "invalid without notification_channel_id" do
      changeset =
        NotificationChannelRecipient.changeset(%NotificationChannelRecipient{}, %{
          email: "alice@example.com"
        })

      refute changeset.valid?
    end
  end

  describe "add_recipient/2" do
    test "creates a recipient with a token and expiry", %{channel: channel} do
      assert {:ok, recipient} = Delivery.add_recipient(channel.id, "alice@example.com")
      assert recipient.email == "alice@example.com"
      assert recipient.token != nil
      assert recipient.token_expires_at != nil
      assert recipient.verified_at == nil
    end

    test "returns error for duplicate email in same channel", %{channel: channel} do
      {:ok, _} = Delivery.add_recipient(channel.id, "alice@example.com")
      assert {:error, changeset} = Delivery.add_recipient(channel.id, "alice@example.com")
      assert "has already been added to this channel" in errors_on(changeset).email
    end

    test "returns error for invalid email format", %{channel: channel} do
      assert {:error, changeset} = Delivery.add_recipient(channel.id, "not-valid")
      assert "has invalid format" in errors_on(changeset).email
    end
  end

  describe "verify_recipient/1" do
    test "marks recipient as verified and clears token", %{channel: channel} do
      {:ok, recipient} = Delivery.add_recipient(channel.id, "bob@example.com")

      assert {:ok, verified} = Delivery.verify_recipient(recipient.token)
      assert verified.verified_at != nil
      assert verified.token == nil
      assert verified.token_expires_at == nil
    end

    test "returns not_found for unknown token", %{channel: _channel} do
      assert {:error, :not_found} = Delivery.verify_recipient("unknowntoken")
    end

    test "returns expired for an expired token", %{channel: channel} do
      {:ok, recipient} = Delivery.add_recipient(channel.id, "carol@example.com")

      past =
        NaiveDateTime.add(NaiveDateTime.utc_now(), -1, :second) |> NaiveDateTime.truncate(:second)

      recipient
      |> NotificationChannelRecipient.changeset(%{token_expires_at: past})
      |> Holter.Repo.update!()

      assert {:error, :expired} = Delivery.verify_recipient(recipient.token)
    end
  end

  describe "list_verified_emails/1" do
    test "returns only verified email addresses", %{channel: channel} do
      {:ok, r1} = Delivery.add_recipient(channel.id, "verified@example.com")
      {:ok, _r2} = Delivery.add_recipient(channel.id, "pending@example.com")

      Delivery.verify_recipient(r1.token)

      assert Delivery.list_verified_emails(channel.id) == ["verified@example.com"]
    end
  end

  describe "remove_recipient/1" do
    test "deletes the recipient", %{channel: channel} do
      {:ok, recipient} = Delivery.add_recipient(channel.id, "delete@example.com")

      Delivery.remove_recipient(recipient.id)

      assert Delivery.list_recipients(channel.id) == []
    end
  end

  describe "resend_recipient_verification/1" do
    import Swoosh.TestAssertions

    test "rotates the recipient's token", %{channel: channel} do
      {:ok, original} = Delivery.add_recipient(channel.id, "rotate@example.com")
      {:ok, refreshed} = Delivery.resend_recipient_verification(original.id)
      assert refreshed.token != original.token
    end

    test "ships a fresh verification email to the recipient address", %{channel: channel} do
      {:ok, recipient} = Delivery.add_recipient(channel.id, "fresh@example.com")
      {:ok, _} = Delivery.resend_recipient_verification(recipient.id)
      assert_email_sent(to: "fresh@example.com")
    end

    test "returns {:error, :not_found} for an unknown recipient id" do
      assert {:error, :not_found} =
               Delivery.resend_recipient_verification(Ecto.UUID.generate())
    end

    test "returns {:error, :already_verified} for a verified recipient", %{channel: channel} do
      {:ok, recipient} = Delivery.add_recipient(channel.id, "done@example.com")
      Delivery.verify_recipient(recipient.token)
      assert {:error, :already_verified} = Delivery.resend_recipient_verification(recipient.id)
    end
  end
end
