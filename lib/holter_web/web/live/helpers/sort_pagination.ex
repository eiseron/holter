defmodule HolterWeb.LiveView.SortPagination do
  @moduledoc """
  Shared helpers for sort-state and pagination URL building in LiveViews.
  """

  import Phoenix.Component, only: [assign: 3]

  def assign_sort_info(socket, path, sortable_cols, filters) do
    sort_info = Map.new(sortable_cols, fn col -> {col, build_sort_col(path, filters, col)} end)
    assign(socket, :sort_info, sort_info)
  end

  def build_sort_col(path, filters, col_key) do
    active = to_string(filters.sort_by) == col_key

    next_dir =
      cond do
        active and filters.sort_dir == "asc" -> "desc"
        active -> "asc"
        true -> "desc"
      end

    new_filters = Map.merge(filters, %{sort_by: col_key, sort_dir: next_dir, page: 1})

    %{
      url: path <> "?" <> encode_filters(new_filters),
      active: active,
      dir: if(active, do: filters.sort_dir)
    }
  end

  def assign_page_links(socket, path, filters) do
    %{page_number: page, total_pages: total} = socket.assigns

    page_url = fn p -> path <> "?" <> encode_filters(Map.put(filters, :page, p)) end

    socket
    |> assign(:prev_page_url, if(page > 1, do: page_url.(page - 1)))
    |> assign(:next_page_url, if(page < total, do: page_url.(page + 1)))
    |> assign(
      :page_links,
      for(p <- max(1, page - 2)..min(total, page + 2), do: {p, page_url.(p)})
    )
  end

  @non_url_params [:id, :workspace_slug, :timezone, "id", "workspace_slug", "timezone"]

  def encode_filters(filters) do
    filters
    |> Enum.reject(fn {k, v} ->
      is_nil(v) or v == "" or k in @non_url_params
    end)
    |> Enum.sort_by(fn {k, _} -> to_string(k) end)
    |> URI.encode_query()
  end
end
