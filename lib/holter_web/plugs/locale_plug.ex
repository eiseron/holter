defmodule HolterWeb.Plugs.LocalePlug do
  @moduledoc """
  Coordinator. Resolves the effective UI locale for the current HTTP
  request and stamps `:current_locale` into `conn.assigns` plus the
  process-dictionary slot read by every `gettext()` call.

  Inputs are extracted from the conn:

  * `?locale=` query parameter
  * `:current_workspace` assign (when an upstream plug or scope
    populates it; today only path-resolved workspace slugs in the
    LiveView session pick that up — for dead renders the workspace
    tier is `nil` and falls through)
  * `accept-language` request header

  The user-preference tier (`users.preferred_locale`) is intentionally
  resolved later by `HolterWeb.Hooks.LocaleHook` once the LiveView
  process owns its assigns. This avoids a per-request DB lookup on
  every plain HTTP request and accepts at most a one-frame mismatch
  during the dead render.
  """

  @behaviour Plug

  alias Eiseron.I18n.{Locale, Resolver}

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    accept_language = get_accept_language(conn)

    locale =
      Resolver.resolve(%{
        url_param: conn.params["locale"],
        user_preferred: nil,
        workspace_default: workspace_default_from_assigns(conn),
        accept_language: accept_language,
        fallback: Locale.default()
      })

    Gettext.put_locale(HolterWeb.Gettext, locale)

    conn
    |> Plug.Conn.put_session("accept_language", accept_language)
    |> Plug.Conn.assign(:current_locale, locale)
  end

  defp workspace_default_from_assigns(conn) do
    case Map.get(conn.assigns, :current_workspace) do
      %{default_locale: locale} -> locale
      _ -> nil
    end
  end

  defp get_accept_language(conn) do
    case Plug.Conn.get_req_header(conn, "accept-language") do
      [value | _] -> value
      _ -> nil
    end
  end
end
