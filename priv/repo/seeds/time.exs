defmodule Holter.Seeds.Time do
  @moduledoc false

  @minute 60
  @hour 60 * @minute
  @day 24 * @hour

  def minute, do: @minute
  def hour, do: @hour
  def day, do: @day

  def ago(seconds) do
    DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(-seconds, :second)
  end

  def ahead(seconds) do
    DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(seconds, :second)
  end
end
