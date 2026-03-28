defmodule HolterWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use HolterWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="app-header">
      <a href="/" class="app-header-brand">
        <img src={~p"/images/holter-white.svg"} class="app-header-logo" alt="Holter" />
        <span class="app-header-wordmark">Holter</span>
      </a>

      <nav class="app-header-nav">
        <.link href={~p"/monitoring/dashboard"} class="app-header-nav-link active">Monitors</.link>
        <.link href="#" class="app-header-nav-link">Network</.link>
        <.link href="#" class="app-header-nav-link">Incidents</.link>
      </nav>

      <div class="app-header-end">
        <.button variant="secondary" size="sm">Documentation</.button>
        <.button variant="primary" size="sm">Deploy Status</.button>
      </div>
    </header>

    <main class="h-container">
      <div class="h-content-wrapper">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end
end
