defmodule Holter.System.Workspaces do
  @moduledoc """
  Read-only coordinator for cross-workspace listing from the admin panel.
  """

  import Ecto.Query

  alias Holter.Monitoring.Models.Workspace
  alias Holter.Pagination
  alias Holter.Repo

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
