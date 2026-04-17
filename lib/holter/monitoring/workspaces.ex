defmodule Holter.Monitoring.Workspaces do
  @moduledoc false

  alias Holter.Monitoring.Workspace
  alias Holter.Repo

  def create_workspace(attrs) do
    %Workspace{}
    |> Workspace.changeset(attrs)
    |> Repo.insert()
  end

  def get_workspace_by_slug(slug) do
    case Repo.get_by(Workspace, slug: slug) do
      nil -> {:error, :not_found}
      workspace -> {:ok, workspace}
    end
  end

  def get_workspace!(id), do: Repo.get!(Workspace, id)

  def get_workspace_by_slug!(slug) do
    Repo.get_by!(Workspace, slug: slug)
  end

  def update_workspace(%Workspace{} = workspace, attrs) do
    workspace
    |> Workspace.changeset(attrs)
    |> Repo.update()
  end

  def mark_check_triggered(%Workspace{} = workspace) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    workspace
    |> Workspace.changeset(%{last_check_triggered_at: now})
    |> Repo.update()
  end
end
