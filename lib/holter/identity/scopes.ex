defmodule Holter.Identity.Scopes do
  @moduledoc """
  Single source of truth for the API scope vocabulary used by API
  tokens. Scopes are opaque strings of the form `<verb>:<resource>`
  with consistent plural entity names. Tokens carry a list of scopes;
  each API endpoint demands one specific scope.
  """

  @scopes ~w(
    read:workspaces
    read:monitors
    write:monitors
    read:logs
    read:metrics
    read:incidents
    read:channels
    write:channels
    ping:channels
    read:delivery_logs
  )

  def all, do: @scopes

  def valid?(scope) when is_binary(scope), do: scope in @scopes
  def valid?(_), do: false

  def all_valid?(scopes) when is_list(scopes), do: Enum.all?(scopes, &valid?/1)
  def all_valid?(_), do: false
end
