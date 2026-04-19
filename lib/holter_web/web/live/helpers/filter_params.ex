defmodule HolterWeb.LiveView.FilterParams do
  @moduledoc false

  def normalize(params, valid_keys) do
    for {k, v} <- params, k in valid_keys, into: %{} do
      {String.to_existing_atom(k), v}
    end
  end

  def cast_integer(filters, key, default) do
    value =
      case Map.get(filters, key) do
        v when is_binary(v) -> String.to_integer(v)
        v when is_integer(v) -> v
        _ -> default
      end

    Map.put(filters, key, value)
  end

  def validate_sort(filters, sortable_cols, default_col) do
    sort_by = if filters.sort_by in sortable_cols, do: filters.sort_by, else: default_col
    sort_dir = if filters.sort_dir in ~w(asc desc), do: filters.sort_dir, else: "desc"
    %{filters | sort_by: sort_by, sort_dir: sort_dir}
  end
end
