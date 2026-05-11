defmodule Holter.Emails.Layout do
  @moduledoc """
  Outer chrome shared by every Holter notification email.

  Every visible element carries an inline `style` attribute so the
  message renders identically in clients that strip or ignore `<style>`
  blocks (Gmail web, Outlook 365). No runtime CSS inliner is needed.

  Mirrors the dark Holter design system: graphite background, dark
  surface card, cyber-blue accent, square corners.
  """
  use Phoenix.Component

  use Gettext, backend: HolterWeb.Gettext

  attr :title, :string, required: true
  attr :preheader, :string, default: nil
  attr :locale, :string, default: "en"
  slot :inner_block, required: true
  slot :footer

  def html(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang={@locale}>
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="color-scheme" content="dark" />
        <meta name="supported-color-schemes" content="dark" />
        <title>{@title}</title>
      </head>
      <body style="margin: 0; padding: 0; background-color: #121212; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif; color: #fafafa;">
        <div
          :if={@preheader}
          style="display: none !important; visibility: hidden; opacity: 0; height: 0; width: 0; overflow: hidden; mso-hide: all;"
        >
          {@preheader}
        </div>
        <div style="width: 100%; padding: 24px 12px; background-color: #121212;">
          <div style="max-width: 600px; margin: 0 auto;">
            <div style="padding: 16px 0; text-align: left;">
              <span style="font-size: 20px; font-weight: 700; letter-spacing: 0.5px; color: #37b9ff; text-decoration: none;">
                Holter
              </span>
            </div>
            <div style="background-color: #1a1a1a; border: 1px solid #2a2a2a; padding: 32px;">
              {render_slot(@inner_block)}
            </div>
            <div style="padding: 16px 4px; font-size: 12px; line-height: 1.5; color: #a6a6a6;">
              {render_slot(@footer)}
              <p style="margin: 12px 0 0 0; color: #a6a6a6;">
                {dgettext("emails", "Holter is the uptime and incident monitor from Eiseron.")}
              </p>
            </div>
          </div>
        </div>
      </body>
    </html>
    """
  end

  @doc """
  Wraps the body of a plain-text email with the Holter wordmark header and
  a legal footer. Receives the rendered text body as a string.
  """
  @spec text(String.t(), keyword) :: String.t()
  def text(body, opts \\ []) when is_binary(body) do
    footer = Keyword.get(opts, :footer, "")

    [
      "Holter",
      "",
      String.trim_trailing(body),
      footer_section(footer),
      tagline()
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
    |> Kernel.<>("\n")
  end

  defp footer_section(""), do: ""
  defp footer_section(footer), do: String.trim_trailing(footer)

  defp tagline do
    "-- " <>
      dgettext("emails", "Holter is the uptime and incident monitor from Eiseron.")
  end
end
