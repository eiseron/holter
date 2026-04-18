defmodule HolterWeb.Components.Table do
  @moduledoc false
  use HolterWeb, :component

  @doc """
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
    attr :sort_url, :string
    attr :sort_active, :boolean
    attr :sort_dir, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <figure class="h-table-wrapper">
      <table class="h-table h-table-zebra">
        <thead>
          <tr>
            <th :for={col <- @col}>
              <%= if col[:sort_url] do %>
                <.link patch={col[:sort_url]} class="h-table-sort-header">
                  {col[:label]}
                  <span :if={col[:sort_active]} class="h-sort-indicator">
                    {if col[:sort_dir] == "asc", do: "↑", else: "↓"}
                  </span>
                </.link>
              <% else %>
                {col[:label]}
              <% end %>
            </th>
            <th :if={@action != []}>
              <span class="h-sr-only">{gettext("Actions")}</span>
            </th>
          </tr>
        </thead>
        <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
          <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
            <td
              :for={col <- @col}
              phx-click={@row_click && @row_click.(row)}
              class={@row_click && "h-table-row-click"}
            >
              {render_slot(col, @row_item.(row))}
            </td>
            <td :if={@action != []} class="h-table-actions">
              <div class="h-flex-gap-4">
                <%= for action <- @action do %>
                  {render_slot(action, @row_item.(row))}
                <% end %>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </figure>
    """
  end
end
