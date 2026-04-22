defmodule HolterWeb.Web.Delivery.NotificationChannelLive.Logs do
  use HolterWeb, :delivery_live_view

  import HolterWeb.LiveView.SortPagination

  alias Holter.Delivery
  alias Holter.Delivery.ChannelLogs
  alias Holter.Monitoring
  alias HolterWeb.LiveView.FilterParams

  @sortable_cols ~w(attempted_at state)
  @valid_filter_keys ~w(status start_date end_date page page_size sort_by sort_dir)

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Delivery.get_channel(id) do
      {:ok, channel} ->
        {:ok, workspace} = Monitoring.get_workspace(channel.workspace_id)

        {:ok,
         socket
         |> assign(:workspace, workspace)
         |> assign(:channel, channel)
         |> assign(:page_title, gettext("Delivery Logs"))
         |> assign(:logs, [])
         |> assign(:filters, %{})
         |> assign(:page_number, 1)
         |> assign(:total_pages, 1)
         |> assign(:form, to_form(%{}, as: "filters"))}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Not found"))
         |> push_navigate(to: "/")}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = parse_filters(params, socket.assigns[:timezone] || "Etc/UTC")
    pagination = Delivery.list_channel_logs(socket.assigns.channel, filters)
    form = to_form(Map.new(filters, fn {k, v} -> {Atom.to_string(k), v} end), as: "filters")
    path = ~p"/delivery/notification-channels/#{socket.assigns.channel.id}/logs"

    {:noreply,
     socket
     |> assign(pagination)
     |> assign(:filters, filters)
     |> assign(:form, form)
     |> assign(:patch_path, path)
     |> assign_page_links(path, filters)
     |> assign_sort_info(%{path: path, sortable_cols: @sortable_cols, filters: filters})}
  end

  @impl true
  def handle_event("filter_updated", %{"filters" => params}, socket) do
    form_filters =
      params
      |> Map.new(fn {k, v} -> {k, empty_to_nil(v)} end)
      |> Enum.reject(fn {k, v} -> is_nil(v) or k in ["sort_by", "sort_dir"] end)
      |> Map.new()

    current_sort = %{
      sort_by: socket.assigns.filters.sort_by,
      sort_dir: socket.assigns.filters.sort_dir
    }

    {:noreply,
     push_patch(socket,
       to:
         socket.assigns.patch_path <>
           "?" <> encode_filters(Map.merge(current_sort, form_filters))
     )}
  end

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value

  defp parse_filters(params, timezone) do
    %{
      status: nil,
      start_date: nil,
      end_date: nil,
      timezone: timezone,
      page: 1,
      page_size: 50,
      sort_by: "attempted_at",
      sort_dir: "desc"
    }
    |> Map.merge(FilterParams.normalize(params, @valid_filter_keys))
    |> Map.put(:timezone, timezone)
    |> FilterParams.cast_integer(:page, 1)
    |> FilterParams.cast_integer(:page_size, 50)
    |> FilterParams.validate_sort(@sortable_cols, "attempted_at")
  end

  defp classify_delivery_status(job), do: ChannelLogs.classify_delivery_status(job)
  defp format_event_type(job), do: ChannelLogs.format_event_type(job)
end
