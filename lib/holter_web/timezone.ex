defmodule HolterWeb.Timezone do
  @moduledoc false

  @default_format "%Y-%m-%d %H:%M:%S"

  def format_datetime(nil, _timezone), do: ""

  def format_datetime(dt, timezone) do
    dt
    |> shift_or_utc(timezone)
    |> Calendar.strftime(@default_format)
  end

  def shift_or_utc(dt, timezone) do
    case DateTime.shift_zone(dt, timezone) do
      {:ok, local} -> local
      _ -> dt
    end
  end

  def local_day_boundaries(date_str, timezone) do
    with {:ok, date} <- Date.from_iso8601(date_str),
         {:ok, start_local} <- DateTime.new(date, ~T[00:00:00], timezone),
         {:ok, end_local} <- DateTime.new(date, ~T[23:59:59], timezone),
         {:ok, start_utc} <- DateTime.shift_zone(start_local, "Etc/UTC"),
         {:ok, end_utc} <- DateTime.shift_zone(end_local, "Etc/UTC") do
      {:ok, start_utc, end_utc}
    else
      _ -> :error
    end
  end

  def valid_timezone?(tz) do
    match?({:ok, _}, DateTime.shift_zone(DateTime.utc_now(), tz))
  end

  def short_cause(nil), do: nil

  def short_cause(cause) do
    case String.split(cause, ": ", parts: 2) do
      [prefix, _detail] -> prefix
      _ -> cause
    end
  end
end
