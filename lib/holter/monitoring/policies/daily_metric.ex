defmodule Holter.Monitoring.Policies.DailyMetric do
  @moduledoc """
  Authorization policy for `Holter.Monitoring.Models.DailyMetric`.

  Daily metrics are written by the aggregator. Users only read them,
  scoped to the parent monitor's workspace.

  | action  | minimum role |
  | ------- | ------------ |
  | `:read` | member       |

  Subject is the parent `%Monitor{}`.
  """

  @behaviour Bodyguard.Policy

  import Ecto.Query, only: [from: 2]

  alias Holter.Identity.Memberships
  alias Holter.Identity.Models.User
  alias Holter.Monitoring.Models.{Monitor, Workspace}

  @doc """
  Filters a DailyMetric query down to metrics whose monitor lives in a
  workspace the user can access.
  """
  def scope(query, %User{} = user) do
    from d in query,
      join: m in Monitor,
      on: m.id == d.monitor_id,
      where: m.workspace_id in subquery(Memberships.accessible_workspace_ids_subquery(user))
  end

  @impl true
  def authorize(_action, :system, _subject), do: :ok

  def authorize(:read, %User{} = user, %Monitor{workspace_id: workspace_id}) do
    if Memberships.member?(user, %Workspace{id: workspace_id}),
      do: :ok,
      else: {:error, :unauthorized}
  end

  def authorize(_action, _user, _subject), do: {:error, :unauthorized}
end
