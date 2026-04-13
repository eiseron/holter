defmodule Holter.Observability do
  @moduledoc """
  System-wide observability metadata provider.
  Centralizes information about node, application, Elixir, and Phoenix versions.
  """

  @doc """
  Returns a map of system and machine information.
  This data is cached in a module attribute for performance.
  """
  def system_versions do
    %{
      node: to_string(Node.self()),
      hostname: get_hostname(),
      holter_version: vsn(:holter),
      elixir_version: System.version(),
      otp_version: System.otp_release(),
      phoenix_version: vsn(:phoenix)
    }
  end

  defp vsn(app), do: Application.spec(app, :vsn) |> to_string()

  defp get_hostname do
    case :inet.gethostname() do
      {:ok, name} -> to_string(name)
      _ -> "unknown"
    end
  end
end
