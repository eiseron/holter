defmodule HolterWeb.Components.Monitoring.StatusPill do
  @moduledoc false
  use HolterWeb, :component

  @doc """
  Renders a status pill badge for monitor log entries.
  """
  attr :status, :atom, required: true
  attr :status_code, :integer, default: nil

  def status_pill(assigns) do
    ~H"""
    <span
      class={"h-status-pill h-status-#{@status}"}
      data-role="log-status"
      data-status={@status}
    >
      {@status |> to_string() |> String.upcase()}
      <span :if={@status_code}>({@status_code})</span>
    </span>
    """
  end
end
