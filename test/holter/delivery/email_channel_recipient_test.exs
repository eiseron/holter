defmodule Holter.Delivery.EmailChannelRecipientTest do
  use Holter.DataCase, async: true

  alias Holter.Delivery.{EmailChannelRecipient, EmailChannels}

  setup do
    workspace = workspace_fixture()

    {:ok, channel} =
      EmailChannels.create(%{
        workspace_id: workspace.id,
        name: "Email Channel",
        address: "primary@example.com"
      })

    %{channel: channel, email_channel_id: channel.id}
  end

  describe "EmailChannelRecipient.changeset/2" do
    test "valid with required fields", %{email_channel_id: email_channel_id} do
      changeset =
        EmailChannelRecipient.changeset(%EmailChannelRecipient{}, %{
          email_channel_id: email_channel_id,
          email: "alice@example.com"
        })

      assert changeset.valid?
    end

    test "invalid without email", %{email_channel_id: email_channel_id} do
      changeset =
        EmailChannelRecipient.changeset(%EmailChannelRecipient{}, %{
          email_channel_id: email_channel_id
        })

      assert "can't be blank" in errors_on(changeset).email
    end

    test "invalid with bad email format", %{email_channel_id: email_channel_id} do
      changeset =
        EmailChannelRecipient.changeset(%EmailChannelRecipient{}, %{
          email_channel_id: email_channel_id,
          email: "not-an-email"
        })

      assert "has invalid format" in errors_on(changeset).email
    end

    test "invalid without email_channel_id" do
      changeset =
        EmailChannelRecipient.changeset(%EmailChannelRecipient{}, %{email: "alice@example.com"})

      refute changeset.valid?
    end
  end

  describe "add_recipient/2" do
    test "creates a recipient with a token and expiry", %{channel: channel} do
      assert {:ok, recipient} = EmailChannels.add_recipient(channel.id, "alice@example.com")
      assert recipient.email == "alice@example.com"
    end

    test "stamps a verification token on the recipient", %{channel: channel} do
      {:ok, recipient} = EmailChannels.add_recipient(channel.id, "alice@example.com")
      assert is_binary(recipient.token)
    end

    test "stamps an expiry on the verification token", %{channel: channel} do
      {:ok, recipient} = EmailChannels.add_recipient(channel.id, "alice@example.com")
      assert %NaiveDateTime{} = recipient.token_expires_at
    end

    test "starts the recipient unverified", %{channel: channel} do
      {:ok, recipient} = EmailChannels.add_recipient(channel.id, "alice@example.com")
      assert is_nil(recipient.verified_at)
    end

    test "returns error for duplicate email in same channel", %{channel: channel} do
      {:ok, _} = EmailChannels.add_recipient(channel.id, "alice@example.com")
      assert {:error, changeset} = EmailChannels.add_recipient(channel.id, "alice@example.com")
      assert "has already been added to this channel" in errors_on(changeset).email
    end

    test "returns error for invalid email format", %{channel: channel} do
      assert {:error, changeset} = EmailChannels.add_recipient(channel.id, "not-valid")
      assert "has invalid format" in errors_on(changeset).email
    end
  end

  describe "verify_recipient/1" do
    test "marks the recipient as verified", %{channel: channel} do
      {:ok, recipient} = EmailChannels.add_recipient(channel.id, "bob@example.com")
      {:ok, verified} = EmailChannels.verify_recipient(recipient.token)
      assert %NaiveDateTime{} = verified.verified_at
    end

    test "clears the verification token", %{channel: channel} do
      {:ok, recipient} = EmailChannels.add_recipient(channel.id, "bob@example.com")
      {:ok, verified} = EmailChannels.verify_recipient(recipient.token)
      assert is_nil(verified.token)
    end

    test "returns not_found for unknown token" do
      assert {:error, :not_found} = EmailChannels.verify_recipient("unknowntoken")
    end

    test "returns expired for an expired token", %{channel: channel} do
      {:ok, recipient} = EmailChannels.add_recipient(channel.id, "carol@example.com")

      past =
        NaiveDateTime.add(NaiveDateTime.utc_now(), -1, :second) |> NaiveDateTime.truncate(:second)

      recipient
      |> EmailChannelRecipient.changeset(%{token_expires_at: past})
      |> Holter.Repo.update!()

      assert {:error, :expired} = EmailChannels.verify_recipient(recipient.token)
    end
  end

  describe "list_verified_emails/1" do
    test "returns only verified email addresses", %{channel: channel} do
      {:ok, r1} = EmailChannels.add_recipient(channel.id, "verified@example.com")
      {:ok, _r2} = EmailChannels.add_recipient(channel.id, "pending@example.com")

      EmailChannels.verify_recipient(r1.token)

      assert EmailChannels.list_verified_emails(channel.id) == ["verified@example.com"]
    end
  end

  describe "remove_recipient/1" do
    test "deletes the recipient", %{channel: channel} do
      {:ok, recipient} = EmailChannels.add_recipient(channel.id, "delete@example.com")

      EmailChannels.remove_recipient(recipient.id)

      assert EmailChannels.list_recipients(channel.id) == []
    end
  end

  describe "resend_recipient_verification/1" do
    import Swoosh.TestAssertions

    test "rotates the recipient's token", %{channel: channel} do
      {:ok, original} = EmailChannels.add_recipient(channel.id, "rotate@example.com")
      {:ok, refreshed} = EmailChannels.resend_recipient_verification(original.id)
      assert refreshed.token != original.token
    end

    test "ships a fresh verification email to the recipient address", %{channel: channel} do
      {:ok, recipient} = EmailChannels.add_recipient(channel.id, "fresh@example.com")
      {:ok, _} = EmailChannels.resend_recipient_verification(recipient.id)
      assert_email_sent(to: "fresh@example.com")
    end

    test "returns {:error, :not_found} for an unknown recipient id" do
      assert {:error, :not_found} =
               EmailChannels.resend_recipient_verification(Ecto.UUID.generate())
    end

    test "returns {:error, :already_verified} for a verified recipient", %{channel: channel} do
      {:ok, recipient} = EmailChannels.add_recipient(channel.id, "done@example.com")
      EmailChannels.verify_recipient(recipient.token)

      assert {:error, :already_verified} =
               EmailChannels.resend_recipient_verification(recipient.id)
    end
  end
end
