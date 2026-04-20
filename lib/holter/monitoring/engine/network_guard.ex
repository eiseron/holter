defmodule Holter.Monitoring.Engine.NetworkGuard do
  @moduledoc false

  def restricted_ip?(nil), do: false

  def restricted_ip?(ip) do
    trusted = get_trusted_hosts()

    case :inet.parse_address(to_charlist(ip)) do
      {:ok, addr} -> private_network_address?(addr) and ip not in trusted
      _ -> false
    end
  end

  def get_trusted_hosts do
    :holter
    |> Application.get_env(:monitoring, [])
    |> Keyword.get(:trusted_hosts, [])
  end

  def private_network_address?({127, _, _, _}), do: true
  def private_network_address?({10, _, _, _}), do: true
  def private_network_address?({172, s, _, _}) when s >= 16 and s <= 31, do: true
  def private_network_address?({192, 168, _, _}), do: true
  def private_network_address?({169, 254, _, _}), do: true
  def private_network_address?({0, 0, 0, 0}), do: true
  def private_network_address?({0, 0, 0, 0, 0, 0, 0, 1}), do: true
  def private_network_address?(_), do: false
end
