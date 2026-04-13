defmodule Holter.Observability do
  @moduledoc """
  System-wide observability metadata provider.
  Centralizes information about application, Elixir, and Phoenix versions.
  """

  @doc """
  Returns a map of system version information.
  """
  def system_versions do
    %{
      holter_version: Application.spec(:holter, :vsn) |> to_string(),
      elixir_version: System.version(),
      otp_version: System.otp_release(),
      phoenix_version: Application.spec(:phoenix, :vsn) |> to_string()
    }
  end

  @doc """
  Injects standard system metadata into the current Logger process.
  """
  def set_system_metadata do
    Logger.metadata(system_versions())
  end
end
