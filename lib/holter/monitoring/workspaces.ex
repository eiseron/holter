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

  def consume_trigger_budget(%Workspace{} = workspace) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {short_count, short_start} =
      resolve_window(
        workspace.trigger_short_count,
        workspace.trigger_short_window_start,
        Workspace.trigger_short_window_seconds(),
        now
      )

    {long_count, long_start} =
      resolve_window(
        workspace.trigger_long_count,
        workspace.trigger_long_window_start,
        Workspace.trigger_long_window_seconds(),
        now
      )

    cond do
      short_count >= workspace.max_triggers_per_minute ->
        {:error, :short_budget_exhausted}

      long_count >= workspace.max_triggers_per_hour ->
        {:error, :long_budget_exhausted}

      true ->
        apply_budget_increment(
          workspace,
          short_count + 1,
          short_start,
          long_count + 1,
          long_start
        )
    end
  end

  def consume_create_budget(%Workspace{} = workspace) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {short_count, short_start} =
      resolve_window(
        workspace.create_short_count,
        workspace.create_short_window_start,
        Workspace.create_short_window_seconds(),
        now
      )

    {long_count, long_start} =
      resolve_window(
        workspace.create_long_count,
        workspace.create_long_window_start,
        Workspace.create_long_window_seconds(),
        now
      )

    cond do
      short_count >= workspace.max_creates_per_minute ->
        {:error, :create_rate_limited}

      long_count >= workspace.max_creates_per_hour ->
        {:error, :create_rate_limited}

      true ->
        apply_create_budget_increment(
          workspace,
          short_count + 1,
          short_start,
          long_count + 1,
          long_start
        )
    end
  end

  defp resolve_window(_count, nil, _window_seconds, now), do: {0, now}

  defp resolve_window(count, window_start, window_seconds, now) do
    if DateTime.diff(now, window_start) < window_seconds do
      {count, window_start}
    else
      {0, now}
    end
  end

  defp apply_budget_increment(
         %Workspace{} = workspace,
         short_count,
         short_start,
         long_count,
         long_start
       ) do
    workspace
    |> Ecto.Changeset.cast(
      %{
        trigger_short_count: short_count,
        trigger_short_window_start: short_start,
        trigger_long_count: long_count,
        trigger_long_window_start: long_start
      },
      [
        :trigger_short_count,
        :trigger_short_window_start,
        :trigger_long_count,
        :trigger_long_window_start
      ]
    )
    |> Repo.update()
  end

  defp apply_create_budget_increment(
         %Workspace{} = workspace,
         short_count,
         short_start,
         long_count,
         long_start
       ) do
    workspace
    |> Ecto.Changeset.cast(
      %{
        create_short_count: short_count,
        create_short_window_start: short_start,
        create_long_count: long_count,
        create_long_window_start: long_start
      },
      [
        :create_short_count,
        :create_short_window_start,
        :create_long_count,
        :create_long_window_start
      ]
    )
    |> Repo.update()
  end
end
