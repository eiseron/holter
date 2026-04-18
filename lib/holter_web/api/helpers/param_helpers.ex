defmodule HolterWeb.Api.ParamHelpers do
  @moduledoc """
  Shared helpers for parsing and sanitizing query parameters in API controllers.
  """
  def maybe_put_integer(acc, params, {key, atom_key}) do
    case Map.get(params, key) do
      val when is_binary(val) ->
        case Integer.parse(val) do
          {int, ""} -> Map.put(acc, atom_key, int)
          _ -> acc
        end

      val when is_integer(val) ->
        Map.put(acc, atom_key, val)

      _ ->
        acc
    end
  end

  def maybe_put_string(acc, params, {key, atom_key}) do
    case Map.get(params, key) do
      val when is_binary(val) and val != "" -> Map.put(acc, atom_key, val)
      _ -> acc
    end
  end
end
