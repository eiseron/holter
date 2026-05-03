defmodule HolterWeb.Components.Delivery.ChannelForm do
  @moduledoc """
  Shared edit-page scaffold for a notification channel (webhook or email).

  Wraps the page header (back link, title, subtitle, View Logs link, Send Test
  button + cooldown), the form scaffold, the monitor link picker, and the
  delete modal. Type-specific bits go in the slots: `:type_fields`,
  `:secret_card`, `:regenerate_modal`, plus an `:extras` slot for the
  email-only verification banner and CC recipients section.

  The template body lives in `channel_form/channel_form.html.heex`.
  """
  use HolterWeb, :component

  import HolterWeb.Components.BackLink
  import HolterWeb.Components.Button
  import HolterWeb.Components.Delivery.MonitorChannelSelect
  import HolterWeb.Components.Modal
  import HolterWeb.Components.PageContainer

  embed_templates "channel_form/*", suffix: "_template"

  attr :channel, :any, required: true, doc: "WebhookChannel or EmailChannel struct."
  attr :workspace, :any, required: true, doc: "Owning workspace."
  attr :form, :any, required: true, doc: "Phoenix form for the channel."

  attr :form_id, :string,
    required: true,
    doc: "DOM id for the form element (e.g. \"webhook-channel-form\")."

  attr :subtype_label, :string, required: true, doc: "Localized type label."
  attr :logs_path, :string, required: true, doc: "URL of the channel's delivery-logs page."

  attr :workspace_channels_path, :string,
    required: true,
    doc: "URL of the workspace channels list."

  attr :available_monitors, :list, required: true
  attr :linked_monitor_ids, :list, required: true
  attr :cooldown_remaining, :integer, required: true

  slot :extras,
    doc: "Optional slot rendered above the secret card (email verification banner, recipients)."

  slot :secret_card, required: true, doc: "Per-type secret card."
  slot :type_fields, required: true, doc: "Per-type form fields component."

  slot :regenerate_modal,
    required: true,
    doc: "Per-type confirmation modal for the secret regeneration."

  def channel_form(assigns), do: channel_form_template(assigns)
end
