defmodule Holter.Delivery.EmailChannelTest do
  use Holter.DataCase, async: true

  alias Holter.Delivery
  alias Holter.Delivery.EmailChannel
  alias Holter.Repo

  describe "changeset/2" do
    test "is invalid without an address" do
      changeset = EmailChannel.changeset(%EmailChannel{}, %{})
      assert "can't be blank" in errors_on(changeset).address
    end

    test "rejects an address longer than 2048 characters" do
      address = String.duplicate("a", 2050) <> "@example.com"
      changeset = EmailChannel.changeset(%EmailChannel{}, %{address: address})
      assert Enum.any?(errors_on(changeset).address, &String.contains?(&1, "should be at most"))
    end

    test "rejects an address that is not a valid email" do
      changeset = EmailChannel.changeset(%EmailChannel{}, %{address: "not-an-email"})
      assert "must be a valid email address" in errors_on(changeset).address
    end

    test "accepts a well-formed email address" do
      changeset = EmailChannel.changeset(%EmailChannel{}, %{address: "ops@example.com"})
      refute Map.has_key?(errors_on(changeset), :address)
    end
  end

  describe "generate_anti_phishing_code/0" do
    test "uses an 8-character no-confusion alphabet split by a hyphen" do
      assert EmailChannel.generate_anti_phishing_code() =~
               ~r/^[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$/
    end

    test "two consecutive calls return different codes" do
      a = EmailChannel.generate_anti_phishing_code()
      b = EmailChannel.generate_anti_phishing_code()
      assert a != b
    end
  end

  describe "generate_verification_token/0" do
    test "returns a 43-character base64url string (32-byte CSPRNG, no padding)" do
      assert EmailChannel.generate_verification_token() =~ ~r/^[A-Za-z0-9_-]{43}$/
    end

    test "two consecutive calls return different tokens" do
      assert EmailChannel.generate_verification_token() !=
               EmailChannel.generate_verification_token()
    end
  end

  describe "verified?/1" do
    test "returns true when verified_at is set" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      assert EmailChannel.verified?(%EmailChannel{verified_at: now})
    end

    test "returns false when verified_at is nil" do
      refute EmailChannel.verified?(%EmailChannel{verified_at: nil})
    end
  end

  describe "verification fields are server-managed" do
    test "changeset/2 ignores verified_at, verification_token and expiry from external attrs" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      changeset =
        EmailChannel.changeset(%EmailChannel{}, %{
          address: "ops@example.com",
          verified_at: now,
          verification_token: "attempted-spoof",
          verification_token_expires_at: now
        })

      refute Ecto.Changeset.get_change(changeset, :verified_at)
      refute Ecto.Changeset.get_change(changeset, :verification_token)
      refute Ecto.Changeset.get_change(changeset, :verification_token_expires_at)
    end
  end

  describe "uniqueness on notification_channel_id" do
    test "a duplicate insert returns an error tuple" do
      assert {:error, %Ecto.Changeset{}} = duplicate_insert()
    end

    test "the duplicate error names the unique constraint field" do
      {:error, changeset} = duplicate_insert()
      assert "has already been taken" in errors_on(changeset).notification_channel_id
    end
  end

  defp duplicate_insert do
    ws = workspace_fixture()

    {:ok, channel} =
      Delivery.create_channel(%{
        workspace_id: ws.id,
        name: "Email",
        type: :email,
        target: "ops@example.com"
      })

    %EmailChannel{}
    |> EmailChannel.changeset(%{
      notification_channel_id: channel.id,
      address: "duplicate@example.com"
    })
    |> Repo.insert()
  end
end
