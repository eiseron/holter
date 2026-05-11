defmodule Holter.Emails.Renderer do
  @moduledoc """
  Pure helpers that turn HEEx function components into the strings consumed
  by `Swoosh.Email.html_body/2` and `Swoosh.Email.text_body/2`.

  Belongs to the transformer layer of the Sequential Pipeline: no IO, no
  Repo, no clock. The mailer (effector) is responsible for delivering the
  resulting `%Swoosh.Email{}`.

  Each email module exposes its own `html/1` function component that calls
  `Holter.Emails.Layout.html/1` from HEEx. Every visible element in the
  layout and components already carries an inline `style` attribute, so
  the renderer here only needs to invoke the component, serialize the
  safe iolist, and strip Phoenix LiveView's `data-phx-loc` debug attrs
  the dev compiler injects.
  """

  alias Phoenix.HTML.Safe

  @phx_loc_regex ~r/ data-phx-loc="\d+"/
  @phx_debug_comment_regex ~r/<!--\s*(?:<[\w.]+>|<\/[\w.]+>|@caller).*?-->/s

  @spec to_html(fun, map | keyword) :: String.t()
  def to_html(component, assigns) when is_function(component, 1) do
    assigns
    |> Map.new()
    |> component.()
    |> Safe.to_iodata()
    |> IO.iodata_to_binary()
    |> strip_phx_debug_attrs()
    |> strip_phx_debug_comments()
  end

  defp strip_phx_debug_attrs(html), do: Regex.replace(@phx_loc_regex, html, "")
  defp strip_phx_debug_comments(html), do: Regex.replace(@phx_debug_comment_regex, html, "")
end
