defmodule HolterWeb.Components.Delivery.NotificationChannelFormFieldsTest do
  use HolterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import HolterWeb.Components.Delivery.NotificationChannelFormFields

  defp form(params \\ %{}) do
    Phoenix.Component.to_form(params, as: :notification_channel)
  end

  describe "notification_channel_form_fields/1 — webhook type" do
    test "renders name input" do
      html =
        render_component(&notification_channel_form_fields/1,
          form: form(),
          selected_type: :webhook
        )

      assert html =~ "Name"
    end

    test "renders webhook option in type select" do
      html =
        render_component(&notification_channel_form_fields/1,
          form: form(),
          selected_type: :webhook
        )

      assert html =~ "Webhook"
    end

    test "renders email option in type select" do
      html =
        render_component(&notification_channel_form_fields/1,
          form: form(),
          selected_type: :webhook
        )

      assert html =~ "Email"
    end

    test "renders target as text input for webhook type" do
      html =
        render_component(&notification_channel_form_fields/1,
          form: form(),
          selected_type: :webhook
        )

      assert html =~ ~s(type="text")
    end

    test "renders webhook URL placeholder for webhook type" do
      html =
        render_component(&notification_channel_form_fields/1,
          form: form(),
          selected_type: :webhook
        )

      assert html =~ "https://example.com/webhook"
    end

    test "renders webhook help text for webhook type" do
      html =
        render_component(&notification_channel_form_fields/1,
          form: form(),
          selected_type: :webhook
        )

      assert html =~ "HTTP POST"
    end
  end

  describe "notification_channel_form_fields/1 — email type" do
    test "renders target as email input for email type" do
      html =
        render_component(&notification_channel_form_fields/1, form: form(), selected_type: :email)

      assert html =~ ~s(type="email")
    end

    test "renders email address placeholder for email type" do
      html =
        render_component(&notification_channel_form_fields/1, form: form(), selected_type: :email)

      assert html =~ "ops@example.com"
    end

    test "renders email help text for email type" do
      html =
        render_component(&notification_channel_form_fields/1, form: form(), selected_type: :email)

      assert html =~ "primary email address"
    end
  end

  describe "notification_channel_form_fields/1 — locked type" do
    test "type select is disabled when locked_type is true" do
      html =
        render_component(&notification_channel_form_fields/1,
          form: form(),
          selected_type: :webhook,
          locked_type: true
        )

      assert html =~ "disabled"
    end

    test "type select is not disabled when locked_type is false" do
      html =
        render_component(&notification_channel_form_fields/1,
          form: form(),
          selected_type: :webhook,
          locked_type: false
        )

      refute html =~ "disabled"
    end
  end
end
