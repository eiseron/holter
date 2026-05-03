defmodule Holter.Delivery.EmailChannelsTest do
  use Holter.DataCase, async: true

  import Holter.MonitoringFixtures
  import Swoosh.TestAssertions

  alias Holter.Delivery.EmailChannel
  alias Holter.Delivery.EmailChannels

  describe "create/1" do
    test "stores name, workspace_id and address from the attrs" do
      ws = workspace_fixture()
      ws_id = ws.id

      assert {:ok,
              %EmailChannel{
                workspace_id: ^ws_id,
                name: "Ops Email",
                address: "ops@example.com"
              }} =
               EmailChannels.create(%{
                 workspace_id: ws.id,
                 name: "Ops Email",
                 address: "ops@example.com"
               })
    end

    test "auto-generates an anti-phishing code" do
      {:ok, channel} = create_channel()
      assert is_binary(channel.anti_phishing_code)
    end

    test "starts unverified" do
      {:ok, channel} = create_channel()
      assert is_nil(channel.verified_at)
    end

    test "rejects an invalid email address with a semantic error message" do
      ws = workspace_fixture()

      {:error, cs} =
        EmailChannels.create(%{workspace_id: ws.id, name: "Bad", address: "not-an-email"})

      assert "must be a valid email address" in errors_on(cs).address
    end

    test "inherits verified_at from a sibling already verified in the same workspace" do
      ws = workspace_fixture()

      {:ok, first} =
        EmailChannels.create(%{
          workspace_id: ws.id,
          name: "First",
          address: "ops@example.com"
        })

      {:ok, _} = EmailChannels.send_verification(first)
      first = EmailChannels.get!(first.id)
      {:ok, _} = EmailChannels.verify(first.verification_token)

      {:ok, sibling} =
        EmailChannels.create(%{
          workspace_id: ws.id,
          name: "Second",
          address: "ops@example.com"
        })

      refute is_nil(sibling.verified_at)
    end
  end

  describe "list/1" do
    test "returns workspace channels sorted by name" do
      ws = workspace_fixture()
      other = workspace_fixture()

      {:ok, alpha} =
        EmailChannels.create(%{workspace_id: ws.id, name: "Alpha", address: "a@example.com"})

      {:ok, _bravo_other_ws} =
        EmailChannels.create(%{workspace_id: other.id, name: "Bravo", address: "b@example.com"})

      {:ok, charlie} =
        EmailChannels.create(%{workspace_id: ws.id, name: "Charlie", address: "c@example.com"})

      assert Enum.map(EmailChannels.list(ws.id), & &1.id) == [alpha.id, charlie.id]
    end
  end

  describe "send_verification/1" do
    test "ships an email to the channel address" do
      {:ok, channel} = create_channel()
      {:ok, _} = EmailChannels.send_verification(channel)
      assert_email_sent(to: channel.address)
    end

    test "stores a fresh verification token" do
      {:ok, channel} = create_channel()
      {:ok, updated} = EmailChannels.send_verification(channel)
      assert is_binary(updated.verification_token)
    end

    test "stores an expiry on the verification token" do
      {:ok, channel} = create_channel()
      {:ok, updated} = EmailChannels.send_verification(channel)
      assert is_struct(updated.verification_token_expires_at, DateTime)
    end

    test "is a no-op for an already-verified channel" do
      {:ok, channel} = create_channel()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, verified} =
        channel
        |> Ecto.Changeset.change(verified_at: now)
        |> Holter.Repo.update()

      {:ok, ^verified} = EmailChannels.send_verification(verified)
      refute_email_sent()
    end
  end

  describe "verify/1" do
    test "marks verified_at on the channel" do
      {:ok, verified} = verify_freshly_created_channel()
      refute is_nil(verified.verified_at)
    end

    test "clears the verification token" do
      {:ok, verified} = verify_freshly_created_channel()
      assert is_nil(verified.verification_token)
    end

    test "clears the verification token expiry" do
      {:ok, verified} = verify_freshly_created_channel()
      assert is_nil(verified.verification_token_expires_at)
    end

    test "propagates verification to same-address siblings in the workspace" do
      ws = workspace_fixture()

      {:ok, first} =
        EmailChannels.create(%{workspace_id: ws.id, name: "First", address: "ops@example.com"})

      {:ok, second} =
        EmailChannels.create(%{workspace_id: ws.id, name: "Second", address: "ops@example.com"})

      {:ok, _} = EmailChannels.send_verification(first)
      first = EmailChannels.get!(first.id)
      {:ok, _} = EmailChannels.verify(first.verification_token)

      refute is_nil(EmailChannels.get!(second.id).verified_at)
    end

    test "does not bleed verification across workspaces" do
      ws_a = workspace_fixture()
      ws_b = workspace_fixture()

      {:ok, a} =
        EmailChannels.create(%{workspace_id: ws_a.id, name: "A", address: "ops@example.com"})

      {:ok, b} =
        EmailChannels.create(%{workspace_id: ws_b.id, name: "B", address: "ops@example.com"})

      {:ok, _} = EmailChannels.send_verification(a)
      a = EmailChannels.get!(a.id)
      {:ok, _} = EmailChannels.verify(a.verification_token)

      assert is_nil(EmailChannels.get!(b.id).verified_at)
    end

    test "returns :not_found for an unknown token" do
      assert {:error, :not_found} = EmailChannels.verify("nope")
    end

    test "returns :expired for a stale token" do
      {:ok, channel} = create_channel()
      {:ok, _} = EmailChannels.send_verification(channel)
      reloaded = EmailChannels.get!(channel.id)

      stale =
        DateTime.utc_now()
        |> DateTime.add(-1, :hour)
        |> DateTime.truncate(:second)

      reloaded
      |> Ecto.Changeset.change(verification_token_expires_at: stale)
      |> Holter.Repo.update!()

      assert {:error, :expired} = EmailChannels.verify(reloaded.verification_token)
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

  defp create_channel do
    ws = workspace_fixture()

    EmailChannels.create(%{
      workspace_id: ws.id,
      name: "Ops",
      address: "ops-#{System.unique_integer([:positive])}@example.com"
    })
  end

  defp verify_freshly_created_channel do
    {:ok, channel} = create_channel()
    {:ok, _} = EmailChannels.send_verification(channel)

    EmailChannels.get!(channel.id).verification_token
    |> EmailChannels.verify()
  end
end
