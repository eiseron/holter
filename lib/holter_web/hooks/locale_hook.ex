defmodule HolterWeb.Hooks.LocaleHook do
  @moduledoc """
  LiveView `on_mount` coordinator. Resolves the effective UI locale
  for the mounting LV process across the same five tiers as
  `HolterWeb.Plugs.LocalePlug`, but with the user-preference tier
  populated from `socket.assigns.current_user` (set by an earlier
  `UserAuthHook` mount). Calls `Gettext.put_locale/2` for the LV
  process and assigns `:current_locale`.

  Mount this hook AFTER `:require_authenticated` /
  `:assign_current_user` so `current_user` is in scope, and AFTER
  any workspace-loading hook so `current_workspace` is in scope.
  Without those, the corresponding tiers are simply `nil` and the
  resolver falls through.
  """

  import Phoenix.Component, only: [assign: 3]

  alias Holter.I18n.{Locale, Resolver}

  def on_mount(_arg, params, session, socket) do
    locale =
      Resolver.resolve(%{
        url_param: locale_param(params),
        user_preferred: user_preferred(socket),
        workspace_default: workspace_default(socket),
        accept_language: session_accept_language(session),
        fallback: Locale.default()
      })

    Gettext.put_locale(HolterWeb.Gettext, locale)
    {:cont, assign(socket, :current_locale, locale)}
  end

  defp locale_param(%{"locale" => value}) when is_binary(value), do: value
  defp locale_param(_), do: nil

  defp user_preferred(socket) do
    case Map.get(socket.assigns, :current_user) do
      %{preferred_locale: locale} -> locale
      _ -> nil
    end
  end

  defp workspace_default(socket) do
    case Map.get(socket.assigns, :current_workspace) do
      %{default_locale: locale} -> locale
      _ -> nil
    end
  end

  defp session_accept_language(%{"accept_language" => value}) when is_binary(value), do: value
  defp session_accept_language(_), do: nil
end
