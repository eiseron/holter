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

  def restricted_host?(nil), do: true

  def restricted_host?(host) do
    host = host |> String.downcase() |> String.replace("[", "") |> String.replace("]", "")
    trusted = get_trusted_hosts()
    (localhost?(host) or private_ip?(host) or single_token_host?(host)) and host not in trusted
  end

  def localhost?(host) do
    host in ["localhost", "127.0.0.1", "::1", "0.0.0.0", "0"] or
      String.starts_with?(host, "127.") or
      String.starts_with?(host, "::ffff:127.")
  end

  def private_ip?(host) do
    case :inet.parse_address(to_charlist(host)) do
      {:ok, addr} -> private_network_address?(addr)
      _ -> encoded_ip?(host)
    end
  end

  def encoded_ip?(host) do
    is_numeric = Regex.match?(~r/^(0x[0-9a-f]+|[0-9]+)$/i, host)
    is_short_ip = Regex.match?(~r/^[0-9]+\.[0-9]+(\.[0-9]+)?$/, host)
    is_numeric or is_short_ip
  end

  def single_token_host?(host), do: not String.contains?(host, ".")

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
