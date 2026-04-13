defmodule HolterWeb.Api.WorkspaceJSON do
  @moduledoc """
  JSON view for rendering workspace data.
  """
  alias Holter.Monitoring.Workspace

  def show(%{workspace: workspace}) do
    %{data: data(workspace)}
  end

  defp data(%Workspace{} = workspace) do
    %{
      id: workspace.id,
      name: workspace.name,
      slug: workspace.slug,
      retention_days: workspace.retention_days,
      max_monitors: workspace.max_monitors,
      min_interval_seconds: workspace.min_interval_seconds,
      inserted_at: workspace.inserted_at,
      updated_at: workspace.updated_at
    }
  end
end
