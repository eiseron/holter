defmodule Holter.Delivery.Profiles do
  @moduledoc """
  Coordinator for the Delivery bounded context's per-workspace
  configuration aggregate. Currently owns `max_channels` — the
  combined cap across webhook + email channels.

  Mirrors `Holter.Monitoring.Profiles`: each context owns its own
  per-workspace configuration aggregate keyed on `workspace_id`,
  rather than piling fields onto the shared Workspace identity.
  """

  import Ecto.Query

  alias Holter.Delivery.{EmailChannels, WebhookChannels}
  alias Holter.Delivery.Models.WorkspaceProfile
  alias Holter.Repo

  def get_for_workspace!(workspace_id) do
    Repo.get_by!(WorkspaceProfile, workspace_id: workspace_id)
  end

  def get_for_workspace(workspace_id) do
    case Repo.get_by(WorkspaceProfile, workspace_id: workspace_id) do
      nil -> {:error, :not_found}
      profile -> {:ok, profile}
    end
  end

  def update_profile(%WorkspaceProfile{} = profile, attrs) do
    profile
    |> WorkspaceProfile.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns `true` when the workspace has hit `max_channels` across
  webhook + email subtypes combined.
  """
  def at_channel_quota?(workspace_id) do
    profile = get_for_workspace!(workspace_id)
    total = WebhookChannels.count(workspace_id) + EmailChannels.count(workspace_id)
    total >= profile.max_channels
  end

  @doc """
  Acquires a row-level `SELECT ... FOR UPDATE` on the workspace's
  delivery profile inside the current transaction. Concurrent
  channel creates against the same workspace serialise on this lock,
  so two requests cannot both observe `count < max` and each insert
  a new channel beyond the cap.

  Must be called inside an open `Repo.transaction/1`.
  """
  def lock_profile_for_update!(workspace_id) do
    from(p in WorkspaceProfile,
      where: p.workspace_id == ^workspace_id,
      lock: "FOR UPDATE"
    )
    |> Repo.one!()
  end
end
