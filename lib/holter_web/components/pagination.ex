defmodule HolterWeb.Components.Pagination do
  @moduledoc false
  use HolterWeb, :component

  @doc """
  Renders a pagination navigation bar with prev/next and numbered page links.
  """
  attr :prev_page_url, :string, default: nil
  attr :next_page_url, :string, default: nil
  attr :page_links, :list, required: true
  attr :page_number, :integer, required: true
  attr :total_pages, :integer, required: true

  def pagination_nav(assigns) do
    ~H"""
    <div class="h-logs-pagination">
      <div class="h-text-muted h-text-sm" data-role="page-info">
        {gettext("Page %{page_number} of %{total_pages}",
          page_number: @page_number,
          total_pages: @total_pages
        )}
      </div>
      <nav class="h-pagination-nav">
        <.link :if={@prev_page_url} patch={@prev_page_url} class="h-btn h-btn-soft h-pagination-btn">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="14"
            height="14"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <path d="M15 18l-6-6 6-6" />
          </svg>
        </.link>

        <%= for {p, url} <- @page_links do %>
          <.link
            patch={url}
            class={"h-btn h-pagination-btn #{if p == @page_number, do: "h-btn-primary", else: "h-btn-soft"}"}
          >
            {p}
          </.link>
        <% end %>

        <.link :if={@next_page_url} patch={@next_page_url} class="h-btn h-btn-soft h-pagination-btn">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="14"
            height="14"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <path d="M9 18l6-6-6-6" />
          </svg>
        </.link>
      </nav>
    </div>
    """
  end
end
