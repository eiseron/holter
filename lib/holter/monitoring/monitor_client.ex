defmodule Holter.Monitoring.MonitorClient do
  @moduledoc """
  Behaviour for the HTTP client used by the monitoring engine.
  """

  @callback request(keyword()) :: {:ok, Req.Response.t()} | {:error, Exception.t()}
  @callback get_ssl_expiration(String.t()) :: {:ok, DateTime.t()} | {:error, any()}

  defmodule HTTP do
    @moduledoc """
    Default HTTP implementation using Req and Erlang :ssl.
    """
    @behaviour Holter.Monitoring.MonitorClient

    @impl true
    def request(opts) do
      opts
      |> Keyword.put_new(:retry, false)
      |> Req.request()
    end

    @impl true
    def get_ssl_expiration(url) do
      uri = URI.parse(url)
      host = to_charlist(uri.host)
      port = uri.port || 443

      case :ssl.connect(host, port, [verify: :verify_none], 5000) do
        {:ok, socket} ->
          result = extract_expiration(socket)
          :ssl.close(socket)
          result

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp extract_expiration(socket) do
      case :ssl.peercert(socket) do
        {:ok, cert} ->
          {:ok, parse_cert_expiry(cert)}

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp parse_cert_expiry(cert) do
      decoded = :public_key.pkix_decode_cert(cert, :otp)
      tbs_cert = elem(decoded, 1)
      validity = elem(tbs_cert, 7)
      {:Validity, _not_before, not_after} = validity

      not_after
      |> decode_time()
      |> to_datetime()
    end

    defp decode_time({:utcTime, time}), do: time
    defp decode_time({:generalTime, time}), do: time

    defp to_datetime(time_chars) do
      time_str = List.to_string(time_chars)

      # Format: YYMMDDHHMMSSZ or YYYYMMDDHHMMSSZ
      case String.length(time_str) do
        13 -> parse_short_year(time_str)
        15 -> parse_long_year(time_str)
      end
    end

    defp parse_short_year(
           <<y::binary-2, m::binary-2, d::binary-2, h::binary-2, min::binary-2, s::binary-2, "Z">>
         ) do
      year =
        if String.to_integer(y) >= 50,
          do: 1900 + String.to_integer(y),
          else: 2000 + String.to_integer(y)

      create_datetime(year, m, d, h, min, s)
    end

    defp parse_long_year(
           <<y::binary-4, m::binary-2, d::binary-2, h::binary-2, min::binary-2, s::binary-2, "Z">>
         ) do
      create_datetime(String.to_integer(y), m, d, h, min, s)
    end

    defp create_datetime(y, m, d, h, min, s) do
      {:ok, dt, _} = DateTime.from_iso8601("#{y}-#{m}-#{d}T#{h}:#{min}:#{s}Z")
      dt
    end
  end
end
