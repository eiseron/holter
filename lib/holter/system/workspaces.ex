defmodule Holter.System.Workspaces do
  @moduledoc """
  Read-only coordinator for cross-workspace listing and detail loading
  from the admin panel.

  Exposes:

    * `list_workspaces/1` — paginated cross-workspace listing.
    * `get_with_associations!/1` — full detail view: the workspace plus
      its monitoring/delivery profiles, members (with role + user), and
      monitors. Backs the `/admin/workspaces/:id` detail page.
  """

  import Ecto.Query

  alias Holter.Delivery.Models.WorkspaceProfile, as: DeliveryProfile
  alias Holter.Identity.Models.WorkspaceMembership
  alias Holter.Monitoring.Models.Monitor
  alias Holter.Monitoring.Models.Workspace
  alias Holter.Monitoring.Models.WorkspaceProfile, as: MonitoringProfile
  alias Holter.Pagination
  alias Holter.Repo
  alias Holter.Repo.Tenant
  alias Holter.System.Models.AuditLog

  @sortable_columns %{
    "name" => :name,
    "slug" => :slug,
    "inserted_at" => :inserted_at
  }

  def list_workspaces(params \\ %{}) do
    page_size = Pagination.resolve_page_size(params[:page_size], default: 25)

    base_query =
      Workspace
      |> maybe_filter_by_name(params[:name])

    {total, total_pages, current_page} =
      Pagination.calculate(base_query, page_size, params[:page])

    workspaces =
      base_query
      |> apply_sort(params[:sort_by], params[:sort_dir])
      |> Pagination.paginate_query(current_page, page_size)
      |> Repo.all()

    %{
      data: workspaces,
      meta: %{
        page: current_page,
        page_size: page_size,
        total: total,
        total_pages: total_pages
      }
    }
  end

  def sortable_columns, do: Map.keys(@sortable_columns)

  def get_with_associations!(id) do
    workspace = Repo.get!(Workspace, id)

    monitoring_profile = load_monitoring_profile(workspace)
    delivery_profile = load_delivery_profile(workspace)
    members = list_members_for(workspace)
    monitors = list_monitors_for(workspace)
    audit_log = recent_audit_log_for(workspace.id)

    %{
      workspace: workspace,
      monitoring_profile: monitoring_profile,
      delivery_profile: delivery_profile,
      members: members,
      monitors: monitors,
      audit_log: audit_log
    }
  end

  defp load_monitoring_profile(%Workspace{id: id}) do
    Tenant.with_workspace!(id, fn ->
      Repo.get_by(MonitoringProfile, workspace_id: id)
    end)
  end

  defp load_delivery_profile(%Workspace{id: id}) do
    Tenant.with_workspace!(id, fn ->
      Repo.get_by(DeliveryProfile, workspace_id: id)
    end)
  end

  defp list_members_for(%Workspace{id: workspace_id}) do
    Tenant.with_workspace!(workspace_id, fn ->
      Repo.all(
        from m in WorkspaceMembership,
          join: u in Holter.Identity.Models.User,
          on: u.id == m.user_id,
          where: m.workspace_id == ^workspace_id,
          order_by: [asc: m.inserted_at],
          select: %{
            id: m.id,
            role: m.role,
            joined_at: m.inserted_at,
            user_id: u.id,
            user_email: u.email,
            user_status: u.onboarding_status
          }
      )
    end)
  end

  defp list_monitors_for(%Workspace{id: workspace_id}) do
    Tenant.with_workspace!(workspace_id, fn ->
      Repo.all(
        from m in Monitor,
          where: m.workspace_id == ^workspace_id,
          order_by: [desc: m.inserted_at],
          limit: 100
      )
    end)
  end

  defp recent_audit_log_for(workspace_id) do
    resource = "Workspace:" <> workspace_id

    AuditLog
    |> where([a], a.resource == ^resource)
    |> order_by([a], desc: a.occurred_at)
    |> limit(50)
    |> Repo.all()
  end

  defp maybe_filter_by_name(query, nil), do: query
  defp maybe_filter_by_name(query, ""), do: query

  defp maybe_filter_by_name(query, term) when is_binary(term) do
    pattern = "%" <> escape_like(term) <> "%"
    from w in query, where: ilike(w.name, ^pattern) or ilike(w.slug, ^pattern)
  end

  defp apply_sort(query, sort_by, sort_dir) do
    column = Map.get(@sortable_columns, to_string(sort_by || "inserted_at"), :inserted_at)
    direction = if sort_dir == "asc", do: :asc, else: :desc
    order_by(query, [w], [{^direction, field(w, ^column)}])
  end

  defp escape_like(term) do
    term
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end
end
