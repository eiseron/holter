defmodule Holter.Integrations.Policies.Integration do
  @moduledoc """
  Authorization policy for `Holter.Integrations.Models.Integration`.

  | action    | minimum role |
  | --------- | ------------ |
  | `:read`   | member       |
  | `:create` | member       |
  | `:update` | admin        |
  | `:delete` | admin        |

  For `:create`, the subject is the parent `%Workspace{}`.
  For other actions, the subject is the `%Integration{}` itself.
  """

  @behaviour Bodyguard.Policy

  alias Holter.Identity.Memberships
  alias Holter.Identity.Models.User
  alias Holter.Integrations.Models.Integration
  alias Holter.Monitoring.Models.Workspace

  @impl true
  def authorize(_action, :system, _subject), do: :ok

  def authorize(action, %User{} = user, %Integration{workspace_id: workspace_id})
      when action in [:read] do
    require_role(user, %Workspace{id: workspace_id}, :member)
  end

  def authorize(action, %User{} = user, %Integration{workspace_id: workspace_id})
      when action in [:update, :delete] do
    require_role(user, %Workspace{id: workspace_id}, :admin)
  end

  def authorize(:create, %User{} = user, %Workspace{} = workspace) do
    require_role(user, workspace, :member)
  end

  def authorize(_action, _user, _subject), do: {:error, :unauthorized}

  defp require_role(user, workspace, :member) do
    if Memberships.member?(user, workspace), do: :ok, else: {:error, :unauthorized}
  end

  defp require_role(user, workspace, :admin) do
    if Memberships.admin?(user, workspace), do: :ok, else: {:error, :unauthorized}
  end
end
