defmodule Holter.Integrations.Engine.SignatureValidator do
  @moduledoc false

  @timestamp_window_seconds 300

  @spec validate_hmac(map(), DateTime.t()) ::
          :ok | {:error, :invalid_signature | :timestamp_expired}
  def validate_hmac(
        %{raw_body: raw_body, signature: signature, secret: secret, timestamp: timestamp},
        now
      ) do
    with :ok <- validate_timestamp(timestamp, now) do
      compute_hmac_result(raw_body, signature, secret)
    end
  end

  @spec validate_timestamp(binary(), DateTime.t()) :: :ok | {:error, :timestamp_expired}
  def validate_timestamp(timestamp_str, now) do
    case parse_unix_timestamp(timestamp_str) do
      {:ok, ts_dt} -> classify_timestamp_age(ts_dt, now)
      :error -> {:error, :timestamp_expired}
    end
  end

  defp compute_hmac_result(raw_body, signature, secret) do
    expected =
      :crypto.mac(:hmac, :sha256, secret, raw_body)
      |> Base.encode16(case: :lower)

    if Plug.Crypto.secure_compare(expected, signature) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  defp parse_unix_timestamp(str) when is_binary(str) do
    case Integer.parse(str) do
      {unix, ""} -> DateTime.from_unix(unix)
      _ -> :error
    end
  end

  defp parse_unix_timestamp(_), do: :error

  defp classify_timestamp_age(ts_dt, now) do
    age_seconds = DateTime.diff(now, ts_dt, :second)

    if abs(age_seconds) <= @timestamp_window_seconds do
      :ok
    else
      {:error, :timestamp_expired}
    end
  end
end
