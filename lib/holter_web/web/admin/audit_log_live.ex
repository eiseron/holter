defmodule HolterWeb.Web.Admin.AuditLogLive do
  @moduledoc """
  Audit log viewer for the admin panel (BDD 105). Append-only stream of
  every admin action recorded in `audit_logs`. Filters by action,
  resource prefix, and actor; ordered newest-first.

  Backed by `Holter.System.list_audit_logs/1` (no per-row mutations —
  the table is append-only).
  """

  use HolterWeb, :admin_live_view

  import HolterWeb.LiveView.SortPagination

  alias Holter.System
  alias HolterWeb.LiveView.FilterParams

  @sortable_cols ~w(occurred_at)
  @valid_filter_keys ~w(action resource sort_by sort_dir)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Admin · Audit log"))
     |> assign(:rows, [])
     |> assign(:row_count, 0)
     |> assign(:filters, %{})
     |> assign(:form, to_form(%{}, as: "filters"))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = parse_filters(params)

    coordinator_filters =
      [
        action: filters.action,
        resource: filters.resource
      ]
      |> Enum.reject(fn {_k, v} -> v in [nil, ""] end)

    rows = System.list_audit_logs(coordinator_filters)

    form =
      to_form(
        %{
          "action" => filters.action,
          "resource" => filters.resource
        },
        as: "filters"
      )

    path = ~p"/admin/audit-log"

    {:noreply,
     socket
     |> assign(:rows, rows)
     |> assign(:row_count, length(rows))
     |> assign(:filters, filters)
     |> assign(:form, form)
     |> assign(:patch_path, path)
     |> assign_sort_info(%{path: path, sortable_cols: @sortable_cols, filters: filters})}
  end

  @impl true
  def handle_event("filter_updated", %{"filters" => params}, socket) do
    form_filters =
      params
      |> Map.new(fn {k, v} -> {k, empty_to_nil(v)} end)
      |> Enum.reject(fn {k, v} -> is_nil(v) or k in ["sort_by", "sort_dir", "page"] end)
      |> Map.new()

    current_sort = %{
      sort_by: socket.assigns.filters.sort_by,
      sort_dir: socket.assigns.filters.sort_dir
    }

    merged = Map.merge(current_sort, form_filters)
    {:noreply, push_patch(socket, to: socket.assigns.patch_path <> "?" <> encode_filters(merged))}
  end

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value

  defp parse_filters(params) do
    %{
      action: nil,
      resource: nil,
      sort_by: "occurred_at",
      sort_dir: "desc"
    }
    |> Map.merge(FilterParams.normalize(params, @valid_filter_keys))
    |> FilterParams.validate_sort(@sortable_cols, "occurred_at")
  end
end
