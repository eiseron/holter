defmodule Holter.Monitoring.Rdap do
  @moduledoc """
  RDAP (RFC 7483) client for domain registration lookups.

  Owns both the HTTP request against the public ICANN-blessed RDAP
  redirector at `rdap.org` and the JSON-response parser. RDAP servers
  return an `events` array; the entry whose `eventAction` is
  `"expiration"` carries the registration expiry date in `eventDate`.
  """

  @rdap_endpoint "https://rdap.org/domain"
  @receive_timeout 5_000

  def get_expiration(host) when is_binary(host) do
    domain = strip_www(host)
    url = "#{@rdap_endpoint}/#{domain}"

    case Req.get(url, receive_timeout: @receive_timeout, retry: false) do
      {:ok, %Req.Response{status: 200, body: body}} -> parse_expiration(body)
      {:ok, %Req.Response{status: 404}} -> {:error, :domain_not_found}
      {:ok, %Req.Response{status: status}} -> {:error, {:rdap_status, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  def parse_expiration(%{"events" => events}) when is_list(events) do
    case find_expiration_event(events) do
      nil -> {:error, :no_expiration_event}
      event_date -> parse_iso_date(event_date)
    end
  end

  def parse_expiration(_), do: {:error, :no_expiration_event}

  defp strip_www("www." <> rest), do: rest
  defp strip_www(host), do: host

  defp find_expiration_event(events) do
    Enum.find_value(events, fn
      %{"eventAction" => "expiration", "eventDate" => date} -> date
      _ -> nil
    end)
  end

  defp parse_iso_date(date) when is_binary(date) do
    case DateTime.from_iso8601(date) do
      {:ok, dt, _} -> {:ok, DateTime.truncate(dt, :second)}
      {:error, _} -> {:error, :invalid_event_date}
    end
  end

  defp parse_iso_date(_), do: {:error, :invalid_event_date}
end
