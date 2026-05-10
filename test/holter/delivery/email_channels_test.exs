defmodule Holter.Delivery.EmailChannelsTest do
  use Holter.DataCase, async: true

  import Holter.MonitoringFixtures
  import Swoosh.TestAssertions

  alias Holter.Delivery.EmailChannels
  alias Holter.Delivery.Models.EmailChannel
  alias Holter.Delivery.Models.EmailChannelRecipient
  alias Holter.Repo

  describe "create/1" do
    test "stores name and workspace_id from the attrs" do
      ws = workspace_fixture()
      ws_id = ws.id

      assert {:ok, %EmailChannel{workspace_id: ^ws_id, name: "Ops Email"}} =
               EmailChannels.create(%{workspace_id: ws.id, name: "Ops Email"})
    end

    test "auto-generates an anti-phishing code" do
      {:ok, channel} = create_channel()
      assert is_binary(channel.anti_phishing_code)
    end

    test "rejects a blank name with a semantic error message" do
      ws = workspace_fixture()
      {:error, cs} = EmailChannels.create(%{workspace_id: ws.id})
      assert "can't be blank" in errors_on(cs).name
    end
  end

  describe "list/1" do
    test "returns workspace channels sorted by name" do
      ws = workspace_fixture()
      other = workspace_fixture()

      {:ok, alpha} = EmailChannels.create(%{workspace_id: ws.id, name: "Alpha"})
      {:ok, _bravo_other_ws} = EmailChannels.create(%{workspace_id: other.id, name: "Bravo"})
      {:ok, charlie} = EmailChannels.create(%{workspace_id: ws.id, name: "Charlie"})

      assert Enum.map(EmailChannels.list(ws.id), & &1.id) == [alpha.id, charlie.id]
    end
  end

  describe "regenerate_anti_phishing_code/1" do
    test "rotates the code to a fresh value" do
      {:ok, channel} = create_channel()
      original = channel.anti_phishing_code

      {:ok, rotated} = EmailChannels.regenerate_anti_phishing_code(channel)
      assert rotated.anti_phishing_code != original
    end
  end

  describe "delete/1" do
    test "removes the channel" do
      {:ok, channel} = create_channel()
      {:ok, _} = EmailChannels.delete(channel)
      assert {:error, :not_found} = EmailChannels.get(channel.id)
    end
  end

  describe "update/2" do
    test "updates the name" do
      {:ok, channel} = create_channel()
      {:ok, updated} = EmailChannels.update(channel, %{name: "Renamed"})
      assert updated.name == "Renamed"
    end
  end

  describe "apply_staged_changes/2" do
    test "updates channel attrs, inserts pending additions, deletes removed ids in one shot" do
      {:ok, channel} = create_channel()
      {:ok, _kept} = EmailChannels.add_recipient(channel.id, "kept@example.com")
      {:ok, doomed} = EmailChannels.add_recipient(channel.id, "doomed@example.com")

      {:ok, %{channel: updated_channel, added: [added]}} =
        EmailChannels.apply_staged_changes(channel, %{
          attrs: %{"name" => "Renamed"},
          additions: ["new@example.com"],
          removed_ids: [doomed.id]
        })

      remaining =
        channel.id |> EmailChannels.list_recipients() |> Enum.map(& &1.email) |> Enum.sort()

      assert {updated_channel.name, added.email, remaining} ==
               {"Renamed", "new@example.com", ["kept@example.com", "new@example.com"]}
    end

    test "rolls back recipient inserts and deletes when the channel update is invalid" do
      {:ok, channel} = create_channel()
      {:ok, doomed} = EmailChannels.add_recipient(channel.id, "doomed@example.com")

      result =
        EmailChannels.apply_staged_changes(channel, %{
          attrs: %{"name" => String.duplicate("x", 256)},
          additions: ["new@example.com"],
          removed_ids: [doomed.id]
        })

      remaining_emails = Enum.map(EmailChannels.list_recipients(channel.id), & &1.email)

      assert {match?({:error, %Ecto.Changeset{}}, result), remaining_emails} ==
               {true, ["doomed@example.com"]}
    end

    test "rolls back the whole transaction when one addition fails validation" do
      {:ok, channel} = create_channel()
      original_name = channel.name

      result =
        EmailChannels.apply_staged_changes(channel, %{
          attrs: %{"name" => "Renamed"},
          additions: ["good@example.com", "not-an-email"],
          removed_ids: []
        })

      reloaded = EmailChannels.get!(channel.id)
      recipients = EmailChannels.list_recipients(channel.id)

      assert {match?({:error, %Ecto.Changeset{}}, result), reloaded.name, recipients} ==
               {true, original_name, []}
    end

    test "ignores removed_ids that belong to a different channel" do
      {:ok, channel} = create_channel()
      {:ok, other_channel} = create_channel()
      {:ok, foreign} = EmailChannels.add_recipient(other_channel.id, "foreign@example.com")

      result =
        EmailChannels.apply_staged_changes(channel, %{
          attrs: %{"name" => channel.name},
          additions: [],
          removed_ids: [foreign.id]
        })

      assert {match?({:ok, _}, result), Repo.get(EmailChannelRecipient, foreign.id) != nil} ==
               {true, true}
    end

    test "with empty additions and removals, just updates the channel" do
      {:ok, channel} = create_channel()

      assert {:ok, %{channel: %EmailChannel{name: "Renamed"}, added: []}} =
               EmailChannels.apply_staged_changes(channel, %{
                 attrs: %{"name" => "Renamed"},
                 additions: [],
                 removed_ids: []
               })
    end
  end

  describe "resend_recipient_verification/1" do
    test "rotates the verification token for an unverified recipient" do
      {:ok, channel} = create_channel()
      {:ok, original} = EmailChannels.add_recipient(channel.id, "alice@example.com")

      {:ok, refreshed} = EmailChannels.resend_recipient_verification(original.id)

      assert refreshed.token != original.token
    end

    test "dispatches a verification email to the recipient address" do
      {:ok, channel} = create_channel()
      {:ok, recipient} = EmailChannels.add_recipient(channel.id, "alice@example.com")

      {:ok, _} = EmailChannels.resend_recipient_verification(recipient.id)

      assert_email_sent(to: "alice@example.com")
    end

    test "returns :already_verified when the recipient has already confirmed" do
      {:ok, channel} = create_channel()
      {:ok, recipient} = EmailChannels.add_recipient(channel.id, "alice@example.com")
      {:ok, _} = EmailChannels.verify_recipient(recipient.token)

      assert {:error, :already_verified} =
               EmailChannels.resend_recipient_verification(recipient.id)
    end

    test "returns :not_found for an unknown recipient id" do
      assert {:error, :not_found} =
               EmailChannels.resend_recipient_verification(Ecto.UUID.generate())
    end
  end

  defp create_channel do
    ws = workspace_fixture()

    EmailChannels.create(%{
      workspace_id: ws.id,
      name: "Ops-#{System.unique_integer([:positive])}"
    })
  end
end
