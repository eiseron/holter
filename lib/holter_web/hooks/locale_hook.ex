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

  Also handles the `{:locale_updated, locale}` message emitted by the
  quick-switcher LiveComponent: the hook flips the runtime Gettext
  locale and `push_navigate`s to the captured current URI so the LV
  re-mounts. Compile-time `gettext/1` calls in HEEx templates are
  cached by Phoenix LiveView's change tracking — without a re-mount,
  text that was rendered in the old locale would survive the change.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4, push_navigate: 2]

  alias Eiseron.I18n.{Locale, Resolver}

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

    socket =
      socket
      |> assign(:current_locale, locale)
      |> attach_hook(:locale_capture_uri, :handle_params, &capture_uri/3)
      |> attach_hook(:locale_updated, :handle_info, &handle_locale_updated/2)

    {:cont, socket}
  end

  defp capture_uri(_params, uri, socket) when is_binary(uri) do
    {:cont, assign(socket, :current_path, to_path(uri))}
  end

  defp capture_uri(_params, _uri, socket), do: {:cont, socket}

  defp to_path(uri) do
    %URI{path: path, query: query} = URI.parse(uri)
    path = path || "/"
    if query, do: path <> "?" <> query, else: path
  end

  defp handle_locale_updated({:locale_updated, locale}, socket) do
    Gettext.put_locale(HolterWeb.Gettext, locale)
    socket = assign(socket, :current_locale, locale)

    case Map.get(socket.assigns, :current_path) do
      path when is_binary(path) -> {:halt, push_navigate(socket, to: path, replace: true)}
      _ -> {:halt, socket}
    end
  end

  defp handle_locale_updated(_msg, socket), do: {:cont, socket}

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
