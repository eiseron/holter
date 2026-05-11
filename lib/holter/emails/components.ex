defmodule Holter.Emails.Components do
  @moduledoc """
  HEEx function components shared across Holter notification email templates.

  Mirrors the Holter dark design system: graphite/dark-surface backgrounds,
  cyber-blue accent, square corners, no gradients. Inline `style` attributes
  on every element keep the message readable in clients that strip
  `<style>` tags; `Holter.Emails.Renderer` additionally inlines the
  layout's stylesheet via Premailex.
  """
  use Phoenix.Component

  use Gettext, backend: HolterWeb.Gettext

  def brand_blue, do: "#37b9ff"
  def text_default, do: "#fafafa"
  def text_muted, do: "#a6a6a6"
  def border_color, do: "#2a2a2a"
  def surface_alt, do: "#222222"

  attr :href, :string, required: true
  slot :inner_block, required: true

  def cta_button(assigns) do
    ~H"""
    <table role="presentation" cellspacing="0" cellpadding="0" border="0" style="margin: 24px 0;">
      <tr>
        <td style="background-color: #37b9ff;">
          <a
            href={@href}
            style="display: inline-block; padding: 12px 24px; font-size: 16px; font-weight: 600; color: #121212; text-decoration: none; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif; text-transform: uppercase; letter-spacing: 0.5px;"
          >
            {render_slot(@inner_block)}
          </a>
        </td>
      </tr>
    </table>
    """
  end

  slot :inner_block, required: true
  attr :variant, :string, default: "info", values: ~w(info warning success danger)

  def info_box(assigns) do
    palette = %{
      "info" => {"rgba(55, 185, 255, 0.12)", "#37b9ff", "rgba(55, 185, 255, 0.35)"},
      "warning" => {"rgba(245, 158, 11, 0.12)", "#fbbf24", "rgba(245, 158, 11, 0.35)"},
      "success" => {"rgba(55, 185, 255, 0.12)", "#37b9ff", "rgba(55, 185, 255, 0.35)"},
      "danger" => {"rgba(255, 51, 102, 0.12)", "#ff3366", "rgba(255, 51, 102, 0.45)"}
    }

    {bg, fg, border} = Map.fetch!(palette, assigns.variant)
    assigns = assign(assigns, bg: bg, fg: fg, border: border)

    ~H"""
    <div style={"background-color: #{@bg}; color: #{@fg}; border: 1px solid #{@border}; padding: 12px 16px; margin: 16px 0; font-size: 14px; line-height: 1.5;"}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  def kv_row(assigns) do
    ~H"""
    <tr>
      <td style="padding: 6px 0; color: #a6a6a6; font-size: 14px; width: 35%; vertical-align: top;">
        {@label}
      </td>
      <td style="padding: 6px 0; color: #fafafa; font-size: 14px; font-weight: 600; word-break: break-word;">
        {@value}
      </td>
    </tr>
    """
  end

  slot :inner_block, required: true

  def kv_table(assigns) do
    ~H"""
    <table
      role="presentation"
      cellspacing="0"
      cellpadding="0"
      border="0"
      width="100%"
      style="margin: 16px 0; border-top: 1px solid #2a2a2a; border-bottom: 1px solid #2a2a2a;"
    >
      <tbody>
        {render_slot(@inner_block)}
      </tbody>
    </table>
    """
  end

  attr :code, :string, default: nil

  def anti_phishing_footer(assigns) do
    ~H"""
    <div
      :if={@code}
      style="margin-top: 24px; padding: 12px 16px; background-color: #222222; border: 1px solid #2a2a2a; font-size: 13px; line-height: 1.5; color: #a6a6a6;"
    >
      <p style="margin: 0 0 8px 0;">
        <strong style="color: #fafafa;">
          {dgettext("emails", "Verification code:")}
        </strong>
        <code style="font-family: ui-monospace, SFMono-Regular, Menlo, monospace; color: #37b9ff;">
          {@code}
        </code>
      </p>
      <p style="margin: 0 0 6px 0;">
        {dgettext(
          "emails",
          "If you did not expect this email, do not trust messages claiming to be from Holter that omit this code."
        )}
      </p>
      <p style="margin: 0;">
        {dgettext(
          "emails",
          "Do not forward this email to anyone you do not trust — the verification code above is a shared secret that lets the recipient impersonate Holter."
        )}
      </p>
    </div>
    """
  end
end
