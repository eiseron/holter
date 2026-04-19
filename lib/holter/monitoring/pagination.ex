defmodule Holter.Monitoring.Pagination do
  @moduledoc false

  import Ecto.Query
  alias Holter.Repo

  def calculate(query, page_size, requested_page) do
    total_count = Repo.one(from(q in query, select: count(q.id)))
    total_pages = ceil(total_count / page_size) |> max(1)
    current_page = (requested_page || 1) |> min(total_pages) |> max(1)
    {total_pages, current_page}
  end
end
