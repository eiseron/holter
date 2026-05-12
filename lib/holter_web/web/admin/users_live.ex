defmodule HolterWeb.Web.Admin.UsersLive do
  @moduledoc """
  Cross-workspace user listing for the admin panel (BDD 63).
  Supports email substring search, onboarding-status filter, and
  sortable/paginated table. Backed by `Holter.System.Users.list_users/1`.
  Detail page and per-row actions (impersonation, ban, plan grant)
  arrive in subsequent MRs.
  """

  use HolterWeb, :admin_live_view

  import HolterWeb.LiveView.SortPagination

  alias Holter.System
  alias HolterWeb.LiveView.FilterParams

  @sortable_cols ~w(email status inserted_at)
  @valid_filter_keys ~w(email status page page_size sort_by sort_dir)
  @status_options ~w(pending_verification active pending_billing banned)

  def status_label(:pending_verification), do: gettext("Pending verification")
  def status_label(:active), do: gettext("Active")
  def status_label(:pending_billing), do: gettext("Pending billing")
  def status_label(:banned), do: gettext("Banned")
  def status_label(other), do: to_string(other)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Admin · Users"))
     |> assign(:users, [])
     |> assign(:filters, %{})
     |> assign(:page_number, 1)
     |> assign(:total_pages, 1)
     |> assign(:total, 0)
     |> assign(:status_options, @status_options)
     |> assign(:form, to_form(%{}, as: "filters"))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = parse_filters(params)
    %{data: users, meta: meta} = System.list_users(filters)

    form =
      to_form(
        %{
          "email" => filters.email,
          "status" => filters.status
        },
        as: "filters"
      )

    path = ~p"/admin/users"

    {:noreply,
     socket
     |> assign(:users, users)
     |> assign(:filters, filters)
     |> assign(:form, form)
     |> assign(:page_number, meta.page)
     |> assign(:total_pages, meta.total_pages)
     |> assign(:total, meta.total)
     |> assign(:patch_path, path)
     |> assign_page_links(path, filters)
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

    merged = Map.merge(current_sort, form_filters) |> Map.put(:page, 1)
    {:noreply, push_patch(socket, to: socket.assigns.patch_path <> "?" <> encode_filters(merged))}
  end

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value

  defp parse_filters(params) do
    %{
      email: nil,
      status: nil,
      page: 1,
      page_size: 25,
      sort_by: "inserted_at",
      sort_dir: "desc"
    }
    |> Map.merge(FilterParams.normalize(params, @valid_filter_keys))
    |> FilterParams.cast_integer(:page, 1)
    |> FilterParams.cast_integer(:page_size, 25)
    |> FilterParams.validate_sort(@sortable_cols, "inserted_at")
  end
end
