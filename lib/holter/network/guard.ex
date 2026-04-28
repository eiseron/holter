defmodule Holter.Network.Guard do
  @moduledoc false

  import Bitwise

  def restricted_url?(url) when is_binary(url) do
    if String.match?(url, ~r/[\s\x00-\x1f\x7f]/u) do
      {:error, :control_chars}
    else
      check_parsed_url(URI.parse(url))
    end
  end

  def restricted_url?(_), do: {:error, :invalid_scheme}

  def restricted_ip?(nil), do: false

  def restricted_ip?(ip) do
    trusted = get_trusted_hosts()

    case :inet.parse_address(to_charlist(ip)) do
      {:ok, addr} -> private_network_address?(addr) and ip not in trusted
      _ -> false
    end
  end

  def restricted_host?(nil), do: true

  def restricted_host?(host) when is_binary(host) do
    normalized = host |> String.downcase() |> String.replace("[", "") |> String.replace("]", "")
    trusted = get_trusted_hosts()

    classify_normalized_host(normalized) and normalized not in trusted
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
    |> Application.get_env(:network, [])
    |> Keyword.get(:trusted_hosts, [])
  end

  def private_network_address?({127, _, _, _}), do: true
  def private_network_address?({10, _, _, _}), do: true
  def private_network_address?({172, b, _, _}) when b in 16..31, do: true
  def private_network_address?({192, 168, _, _}), do: true
  def private_network_address?({169, 254, _, _}), do: true
  def private_network_address?({0, _, _, _}), do: true

  def private_network_address?({0, 0, 0, 0, 0, 0, 0, 1}), do: true
  def private_network_address?({0, 0, 0, 0, 0, 0, 0, 0}), do: true

  def private_network_address?({0, 0, 0, 0, 0, 0xFFFF, ab, cd}) do
    a = ab >>> 8 &&& 0xFF
    b = ab &&& 0xFF
    c = cd >>> 8 &&& 0xFF
    d = cd &&& 0xFF
    private_network_address?({a, b, c, d})
  end

  def private_network_address?({first, _, _, _, _, _, _, _})
      when (first &&& 0xFFC0) == 0xFE80,
      do: true

  def private_network_address?({first, _, _, _, _, _, _, _})
      when (first &&& 0xFE00) == 0xFC00,
      do: true

  def private_network_address?(_), do: false

  defp check_parsed_url(%URI{userinfo: u}) when is_binary(u) and u != "",
    do: {:error, :credentials}

  defp check_parsed_url(%URI{scheme: scheme, host: host})
       when scheme in ["http", "https"] and is_binary(host) and host != "" do
    if restricted_host?(host), do: {:error, :private_host}, else: :ok
  end

  defp check_parsed_url(_uri), do: {:error, :invalid_scheme}

  defp classify_normalized_host(normalized) do
    case :inet.parse_address(to_charlist(normalized)) do
      {:ok, addr} ->
        private_network_address?(addr)

      _ ->
        localhost?(normalized) or encoded_ip?(normalized) or
          single_token_host?(normalized)
    end
  end
end
