defmodule Holter.Delivery.EmailChannelTest do
  use Holter.DataCase, async: true

  alias Holter.Delivery.Models.EmailChannel

  describe "changeset/2" do
    test "is invalid without a name" do
      changeset = EmailChannel.changeset(%EmailChannel{}, %{})
      assert "can't be blank" in errors_on(changeset).name
    end

    test "rejects a name longer than 255 characters" do
      name = String.duplicate("a", 256)
      changeset = EmailChannel.changeset(%EmailChannel{}, %{name: name})
      assert Enum.any?(errors_on(changeset).name, &String.contains?(&1, "should be at most"))
    end

    test "auto-fills the anti-phishing code when missing" do
      changeset = EmailChannel.changeset(%EmailChannel{}, %{name: "Ops"})
      refute is_nil(Ecto.Changeset.get_change(changeset, :anti_phishing_code))
    end

    test "accepts a supported locale" do
      changeset =
        EmailChannel.changeset(%EmailChannel{}, %{address: "ops@example.com", locale: "en"})

      refute Map.has_key?(errors_on(changeset), :locale)
    end

    test "treats nil locale as inherit-from-workspace and does not error" do
      changeset =
        EmailChannel.changeset(%EmailChannel{}, %{address: "ops@example.com", locale: nil})

      refute Map.has_key?(errors_on(changeset), :locale)
    end

    test "rejects an unsupported locale" do
      changeset =
        EmailChannel.changeset(%EmailChannel{}, %{address: "ops@example.com", locale: "fr_FR"})

      assert "is not a supported locale" in errors_on(changeset).locale
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
end
