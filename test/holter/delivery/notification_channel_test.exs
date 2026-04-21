defmodule Holter.Delivery.NotificationChannelTest do
  use Holter.DataCase, async: true

  alias Holter.Delivery.NotificationChannel

  defp valid_attrs(workspace_id, overrides \\ %{}) do
    Map.merge(
      %{
        workspace_id: workspace_id,
        name: "Slack DevOps",
        type: :webhook,
        target: "https://hooks.slack.com/services/XYZ/123"
      },
      overrides
    )
  end

  describe "changeset/2 — required fields" do
    test "is valid with all required fields" do
      ws = workspace_fixture()
      changeset = NotificationChannel.changeset(%NotificationChannel{}, valid_attrs(ws.id))
      assert changeset.valid?
    end

    test "is invalid without name" do
      ws = workspace_fixture()

      changeset =
        NotificationChannel.changeset(%NotificationChannel{}, valid_attrs(ws.id, %{name: nil}))

      assert "can't be blank" in errors_on(changeset).name
    end

    test "is invalid without type" do
      ws = workspace_fixture()

      changeset =
        NotificationChannel.changeset(%NotificationChannel{}, valid_attrs(ws.id, %{type: nil}))

      assert "can't be blank" in errors_on(changeset).type
    end

    test "is invalid without target" do
      ws = workspace_fixture()

      changeset =
        NotificationChannel.changeset(%NotificationChannel{}, valid_attrs(ws.id, %{target: nil}))

      assert "can't be blank" in errors_on(changeset).target
    end

    test "is invalid without workspace_id" do
      changeset =
        NotificationChannel.changeset(
          %NotificationChannel{},
          valid_attrs(nil, %{workspace_id: nil})
        )

      assert "can't be blank" in errors_on(changeset).workspace_id
    end
  end

  describe "changeset/2 — type enum" do
    test "accepts all valid channel types" do
      ws = workspace_fixture()

      for type <- [:email, :webhook] do
        target = if type == :email, do: "user@example.com", else: "https://example.com/hook"

        changeset =
          NotificationChannel.changeset(
            %NotificationChannel{},
            valid_attrs(ws.id, %{type: type, target: target})
          )

        assert changeset.valid?,
               "expected type #{type} to be valid, got: #{inspect(changeset.errors)}"
      end
    end

    test "rejects unknown channel type" do
      ws = workspace_fixture()

      changeset =
        NotificationChannel.changeset(%NotificationChannel{}, valid_attrs(ws.id, %{type: :sms}))

      assert "is invalid" in errors_on(changeset).type
    end
  end

  describe "changeset/2 — target URL validation for webhook" do
    test "rejects non-URL target for webhook type" do
      ws = workspace_fixture()

      changeset =
        NotificationChannel.changeset(
          %NotificationChannel{},
          valid_attrs(ws.id, %{type: :webhook, target: "not-a-url"})
        )

      assert "must be a valid http or https URL" in errors_on(changeset).target
    end

    test "rejects unknown type as invalid" do
      ws = workspace_fixture()

      changeset =
        NotificationChannel.changeset(
          %NotificationChannel{},
          valid_attrs(ws.id, %{type: :slack})
        )

      assert "is invalid" in errors_on(changeset).type
    end

    test "accepts https URL for webhook type" do
      ws = workspace_fixture()

      changeset =
        NotificationChannel.changeset(
          %NotificationChannel{},
          valid_attrs(ws.id, %{type: :webhook, target: "https://example.com/webhook"})
        )

      assert changeset.valid?
    end
  end

  describe "changeset/2 — target email validation" do
    test "accepts valid email for email type" do
      ws = workspace_fixture()

      changeset =
        NotificationChannel.changeset(
          %NotificationChannel{},
          valid_attrs(ws.id, %{type: :email, target: "ops@example.com"})
        )

      assert changeset.valid?
    end

    test "rejects invalid email for email type" do
      ws = workspace_fixture()

      changeset =
        NotificationChannel.changeset(
          %NotificationChannel{},
          valid_attrs(ws.id, %{type: :email, target: "not-an-email"})
        )

      assert "must be a valid email address" in errors_on(changeset).target
    end

    test "rejects URL as email target" do
      ws = workspace_fixture()

      changeset =
        NotificationChannel.changeset(
          %NotificationChannel{},
          valid_attrs(ws.id, %{type: :email, target: "https://example.com"})
        )

      assert "must be a valid email address" in errors_on(changeset).target
    end
  end

  describe "changeset/2 — name length" do
    test "rejects name longer than 255 characters" do
      ws = workspace_fixture()
      long_name = String.duplicate("a", 256)

      changeset =
        NotificationChannel.changeset(
          %NotificationChannel{},
          valid_attrs(ws.id, %{name: long_name})
        )

      assert "should be at most 255 character(s)" in errors_on(changeset).name
    end
  end
end
