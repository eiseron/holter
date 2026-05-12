defmodule Holter.Monitoring.Workspaces do
  @moduledoc false

  alias Holter.Delivery.Models.WorkspaceProfile, as: DeliveryProfile
  alias Holter.Monitoring.Models.{Workspace, WorkspaceProfile}
  alias Holter.Repo
  alias Holter.Repo.Tenant

  @monitoring_profile_attr_keys ~w(
    retention_days max_monitors min_interval_seconds
    last_check_triggered_at
    max_triggers_per_minute max_triggers_per_hour
    max_creates_per_minute max_creates_per_hour
  )a

  @delivery_profile_attr_keys ~w(max_channels)a

  @doc """
  Inserts a workspace, its `Monitoring.WorkspaceProfile`, and its
  `Delivery.WorkspaceProfile` in a single transaction. Profile keys
  can be passed flat at the top level (e.g. `max_monitors: 10,
  max_channels: 25`) — they are routed to the appropriate profile
  changeset internally.

  Both profile inserts are stamped with the freshly-created
  workspace's tenant context so RLS WITH CHECK predicates pass.
  """
  def create_workspace(attrs) do
    {workspace_attrs, monitoring_attrs, delivery_attrs} = split_attrs(attrs)

    Repo.transaction(fn ->
      with {:ok, workspace} <- insert_workspace(workspace_attrs),
           {:ok, monitoring_profile} <-
             insert_monitoring_profile(workspace, monitoring_attrs),
           {:ok, _delivery_profile} <-
             insert_delivery_profile(workspace, delivery_attrs) do
        %{workspace | monitoring_profile: monitoring_profile}
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Lists every workspace globally. The `workspaces` table itself has no
  RLS — workspace identity must be visible before any tenant context
  is set so background workers can iterate and stamp per-row.
  """
  def list_all do
    Repo.all(Workspace)
  end

  def get_workspace_by_slug(slug) do
    case Repo.get_by(Workspace, slug: slug) do
      nil -> {:error, :not_found}
      workspace -> {:ok, workspace}
    end
  end

  def get_workspace(id) do
    case Repo.get(Workspace, id) do
      nil -> {:error, :not_found}
      workspace -> {:ok, workspace}
    end
  end

  def get_workspace!(id), do: Repo.get!(Workspace, id)

  def get_workspace_by_slug!(slug) do
    Repo.get_by!(Workspace, slug: slug)
  end

  def update_workspace(%Workspace{} = workspace, attrs) do
    {workspace_attrs, monitoring_attrs, delivery_attrs} = split_attrs(attrs)

    Repo.transaction(fn ->
      with {:ok, updated} <-
             workspace |> Workspace.changeset(workspace_attrs) |> Repo.update(),
           {:ok, _} <- maybe_update_monitoring_profile(workspace.id, monitoring_attrs),
           {:ok, _} <- maybe_update_delivery_profile(workspace.id, delivery_attrs) do
        updated
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp split_attrs(attrs) do
    normalized = normalize_keys(attrs)

    {monitoring_attrs, rest} = Map.split(normalized, @monitoring_profile_attr_keys)
    {delivery_attrs, workspace_attrs} = Map.split(rest, @delivery_profile_attr_keys)

    {workspace_attrs, monitoring_attrs, delivery_attrs}
  end

  defp normalize_keys(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {k, v} when is_binary(k) -> {safe_to_atom(k), v}
      {k, v} -> {k, v}
    end)
  end

  defp safe_to_atom(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> key
  end

  defp insert_workspace(attrs) do
    %Workspace{}
    |> Workspace.changeset(attrs)
    |> Repo.insert()
  end

  defp insert_monitoring_profile(%Workspace{id: workspace_id}, attrs) do
    Tenant.with_workspace!(workspace_id, fn ->
      %WorkspaceProfile{}
      |> WorkspaceProfile.changeset(Map.put(attrs, :workspace_id, workspace_id))
      |> Repo.insert()
    end)
  end

  defp insert_delivery_profile(%Workspace{id: workspace_id}, attrs) do
    Tenant.with_workspace!(workspace_id, fn ->
      %DeliveryProfile{}
      |> DeliveryProfile.changeset(Map.put(attrs, :workspace_id, workspace_id))
      |> Repo.insert()
    end)
  end

  defp maybe_update_monitoring_profile(_workspace_id, attrs) when map_size(attrs) == 0,
    do: {:ok, :noop}

  defp maybe_update_monitoring_profile(workspace_id, attrs) do
    Tenant.with_workspace!(workspace_id, fn ->
      WorkspaceProfile
      |> Repo.get_by!(workspace_id: workspace_id)
      |> WorkspaceProfile.changeset(attrs)
      |> Repo.update()
    end)
  end

  defp maybe_update_delivery_profile(_workspace_id, attrs) when map_size(attrs) == 0,
    do: {:ok, :noop}

  defp maybe_update_delivery_profile(workspace_id, attrs) do
    Tenant.with_workspace!(workspace_id, fn ->
      DeliveryProfile
      |> Repo.get_by!(workspace_id: workspace_id)
      |> DeliveryProfile.changeset(attrs)
      |> Repo.update()
    end)
  end
end
