defmodule Holter.Integrations.Catalog do
  @moduledoc """
  Pure transformer that builds the list of available integration providers
  from the runtime registry. The list shrinks/grows automatically as provider
  modules are added or removed from `:integration_providers`.
  """

  @doc """
  Builds the catalog from a registry map (`%{atom => module}`).

  Each entry contains the provider's display name, category and icon,
  pulled from the module's `Holter.Integrations.Provider` callbacks.
  """
  def build_catalog(registry) when is_map(registry) do
    registry
    |> Enum.filter(fn {_provider, module} ->
      Code.ensure_loaded?(module) and
        function_exported?(module, :category, 0) and function_exported?(module, :icon, 0)
    end)
    |> Enum.map(fn {provider, module} ->
      %{
        provider: provider,
        display_name: module.display_name(),
        category: module.category(),
        icon: module.icon()
      }
    end)
    |> Enum.sort_by(& &1.display_name)
  end

  @doc "Builds the catalog and tags each entry with the matching workspace integration, if any."
  def build_catalog(registry, integrations) when is_map(registry) and is_list(integrations) do
    connected = Map.new(integrations, &{&1.provider, &1})

    registry
    |> build_catalog()
    |> Enum.map(fn entry ->
      Map.put(entry, :integration, Map.get(connected, entry.provider))
    end)
  end
end
