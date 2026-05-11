defmodule Holter.Delivery.Engine.ChannelFormatter do
  @moduledoc false

  use Gettext, backend: HolterWeb.Gettext

  alias Holter.Delivery.Emails.{AlertDown, AlertTest, AlertUp}
  alias Holter.Delivery.Models.EmailChannel
  alias Holter.Emails.{Layout, Renderer}

  def format_payload(payload, :webhook) do
    {:ok, json} = Jason.encode(payload)
    {json, [{"content-type", "application/json"}]}
  end

  @doc """
  Builds the multipart email payload for an alert. Returns a map carrying
  the rendered subject, plain-text body and HTML body so the dispatcher
  can stamp them onto the `%Swoosh.Email{}` without further rendering.
  """
  @spec format_email(map, EmailChannel.t() | nil) :: %{
          subject: String.t(),
          text: String.t(),
          html: String.t()
        }
  def format_email(payload, channel \\ nil) do
    module = module_for(payload)
    code = anti_phishing_code(channel)

    %{
      subject: module.subject(payload),
      text: render_text(module, payload, code),
      html: Renderer.to_html(&module.html/1, html_assigns(module, payload, code))
    }
  end

  defp module_for(%{event: "monitor_down"}), do: AlertDown
  defp module_for(%{event: "monitor_up"}), do: AlertUp
  defp module_for(%{event: "test_ping"}), do: AlertTest

  defp anti_phishing_code(%EmailChannel{anti_phishing_code: code}) when is_binary(code), do: code
  defp anti_phishing_code(_), do: nil

  defp render_text(module, payload, code) do
    body = payload |> module.text_lines() |> Enum.join("\n")
    Layout.text(body, footer: anti_phishing_text_footer(code))
  end

  defp anti_phishing_text_footer(nil), do: ""

  defp anti_phishing_text_footer(code) do
    [
      gettext("Verification code: %{code}", code: code),
      gettext(
        "If you did not expect this email, do not trust messages claiming to be from Holter that omit this code."
      ),
      gettext(
        "Do not forward this email to anyone you do not trust — the verification code above is a shared secret that lets the recipient impersonate Holter."
      )
    ]
    |> Enum.join("\n")
  end

  defp html_assigns(AlertDown, payload, code) do
    %{
      monitor: payload.monitor,
      incident: Map.get(payload, :incident),
      timestamp: payload.timestamp,
      event: payload.event,
      anti_phishing_code: code
    }
  end

  defp html_assigns(AlertUp, payload, code) do
    html_assigns(AlertDown, payload, code)
  end

  defp html_assigns(AlertTest, payload, code) do
    %{
      channel_name: payload.channel.name,
      timestamp: payload.timestamp,
      anti_phishing_code: code
    }
  end
end
