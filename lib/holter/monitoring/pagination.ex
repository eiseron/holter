defmodule Holter.Monitoring.Pagination do
  @moduledoc false

  import Ecto.Query
  alias Holter.Repo

  @default_page_size 25
  @max_page_size 100

  def resolve_page_size(requested, opts \\ []) do
    max = Keyword.get(opts, :max, @max_page_size)
    default = Keyword.get(opts, :default, @default_page_size)
    (requested || default) |> min(max) |> max(1)
  end

  def calculate(query, page_size, requested_page) do
    total_count = Repo.one(from(q in query, select: count(q.id)))
    total_pages = ceil(total_count / page_size) |> max(1)
    current_page = (requested_page || 1) |> min(total_pages) |> max(1)
    {total_pages, current_page}
  end

  def paginate_query(query, page, page_size) do
    query
    |> limit(^page_size)
    |> offset(^((page - 1) * page_size))
  end
end
