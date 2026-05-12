defmodule Holter.System.Users do
  @moduledoc """
  Read-only coordinator for cross-workspace user lookups from the admin
  panel. Lives under `Holter.System` (not `Holter.Identity`) because
  the calling context is always an admin acting on someone else —
  authorization is gated by `Holter.System.Policies.User`, not by
  Identity's per-resource policies.

  In MR1, exposes a single paginated list with email-substring search
  and onboarding-status filter. MR2 will add `get_with_workspaces!/1`
  to back the user detail page.
  """

  import Ecto.Query

  alias Holter.Identity.Models.User
  alias Holter.Pagination
  alias Holter.Repo

  @sortable_columns %{
    "email" => :email,
    "status" => :onboarding_status,
    "inserted_at" => :inserted_at
  }

  def list_users(params \\ %{}) do
    page_size = Pagination.resolve_page_size(params[:page_size], default: 25)

    base_query =
      User
      |> maybe_filter_by_email(params[:email])
      |> maybe_filter_by_status(params[:status])

    {total_pages, current_page} = Pagination.calculate(base_query, page_size, params[:page])
    total = Repo.aggregate(base_query, :count, :id)

    users =
      base_query
      |> apply_sort(params[:sort_by], params[:sort_dir])
      |> Pagination.paginate_query(current_page, page_size)
      |> Repo.all()

    %{
      data: users,
      meta: %{
        page: current_page,
        page_size: page_size,
        total: total,
        total_pages: total_pages
      }
    }
  end

  def sortable_columns, do: Map.keys(@sortable_columns)

  defp maybe_filter_by_email(query, nil), do: query
  defp maybe_filter_by_email(query, ""), do: query

  defp maybe_filter_by_email(query, term) when is_binary(term) do
    pattern = "%" <> escape_like(term) <> "%"
    from u in query, where: ilike(u.email, ^pattern)
  end

  defp maybe_filter_by_status(query, nil), do: query
  defp maybe_filter_by_status(query, ""), do: query

  defp maybe_filter_by_status(query, status) when is_binary(status) do
    status_atom = String.to_existing_atom(status)
    from u in query, where: u.onboarding_status == ^status_atom
  rescue
    ArgumentError -> query
  end

  defp maybe_filter_by_status(query, status) when is_atom(status) do
    from u in query, where: u.onboarding_status == ^status
  end

  defp apply_sort(query, sort_by, sort_dir) do
    column = Map.get(@sortable_columns, to_string(sort_by || "inserted_at"), :inserted_at)
    direction = if sort_dir == "asc", do: :asc, else: :desc
    order_by(query, [u], [{^direction, field(u, ^column)}])
  end

  defp escape_like(term) do
    term
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end
end
