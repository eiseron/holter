defmodule Holter.I18n.Resolver do
  @moduledoc """
  Pure transformer that picks the effective UI locale for a given
  request or LiveView mount. Walks five tiers in order, validating
  each one against `Holter.I18n.Locale.valid?/1` so stale or unknown
  values transparently fall through.

  Tier order:

      1. URL `?locale=` parameter   (shared links, debugging)
      2. user.preferred_locale      (authenticated user override)
      3. workspace.default_locale   (workspace-scoped routes only)
      4. Accept-Language header     (BCP-47 normalized)
      5. fallback                   (app default, e.g. "pt_BR")

  Coordinators (Plug, Hook) build the input map and call `resolve/1`.
  No I/O here.
  """

  alias Holter.I18n.Locale

  def resolve(%{} = inputs) do
    valid_or_nil(inputs[:url_param]) ||
      valid_or_nil(inputs[:user_preferred]) ||
      valid_or_nil(inputs[:workspace_default]) ||
      Locale.parse_accept_language(inputs[:accept_language]) ||
      Map.fetch!(inputs, :fallback)
  end

  defp valid_or_nil(value) do
    if Locale.valid?(value), do: value, else: nil
  end
end
