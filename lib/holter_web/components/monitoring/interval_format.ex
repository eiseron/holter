defmodule HolterWeb.Components.Monitoring.IntervalFormat do
  @moduledoc """
  Pure formatting helpers for monitor check intervals.

  Renders integer seconds as a compact human label using "h" / "min"
  abbreviations that read the same in en and pt-BR.
  """

  @spec format_label(non_neg_integer()) :: String.t()
  def format_label(seconds) when is_integer(seconds) and seconds >= 0 do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)

    cond do
      hours > 0 and minutes > 0 -> "#{hours} h #{minutes} min"
      hours > 0 -> "#{hours} h"
      true -> "#{minutes} min"
    end
  end
end
