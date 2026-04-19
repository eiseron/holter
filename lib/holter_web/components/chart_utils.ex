defmodule HolterWeb.Components.ChartUtils do
  @moduledoc false

  def map_x(dt, {min_ts, max_ts}, {label_left, svg_width}) do
    ts = DateTime.to_unix(dt)
    label_left + (ts - min_ts) / (max_ts - min_ts) * (svg_width - label_left) * 1.0
  end

  def derive_max_value(items, field, cap) do
    items
    |> Enum.map(&Map.get(&1, field))
    |> Enum.reject(&is_nil/1)
    |> Enum.max(fn -> 0 end)
    |> min(cap)
  end

  def normalize_y(nil, _max, {y_bottom, _y_top, _cap}), do: y_bottom * 1.0
  def normalize_y(value, 0, {_, _, cap} = coords), do: normalize_y(value, cap, coords)

  def normalize_y(value, max, {y_bottom, y_top, cap}) do
    clamped = min(value, cap)
    y_bottom - clamped / max * (y_bottom - y_top) * 1.0
  end
end
