defmodule Holter.Identity.EmailNormalizer do
  @moduledoc """
  Pure transformer that normalizes user-supplied emails before persistence
  or lookup so case-only and whitespace-only variants resolve to the same row.
  """

  def normalize(value) when is_binary(value) do
    value |> String.trim() |> String.downcase()
  end

  def normalize(value), do: value
end
