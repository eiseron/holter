defmodule Holter.Monitoring.DateFilter do
  @moduledoc false

  def parse_to_datetime(date_str, type, timezone) do
    with {:ok, date} <- Date.from_iso8601(date_str),
         time = if(type == :start, do: ~T[00:00:00], else: ~T[23:59:59]),
         {:ok, local_dt} <- DateTime.new(date, time, timezone),
         {:ok, utc_dt} <- DateTime.shift_zone(local_dt, "Etc/UTC") do
      {:ok, utc_dt}
    else
      _ -> :error
    end
  end
end
