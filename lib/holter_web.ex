defmodule HolterWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such as
  controllers, components, channels, and so on.

  This can be used in your application as:

      use HolterWeb, :controller
      use HolterWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: HolterWeb.Layouts]

      import Plug.Conn
      use Gettext, backend: HolterWeb.Gettext

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {HolterWeb.Layouts, :app}

      on_mount HolterWeb.ObservabilityHook

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      import Phoenix.Controller,
        only: [get_csrf_token: 0, get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      unquote(html_helpers())
    end
  end

  def component do
    quote do
      use Phoenix.Component
      import Phoenix.HTML
      import Phoenix.HTML.Form
      use Gettext, backend: HolterWeb.Gettext
      alias Phoenix.LiveView.JS
      unquote(verified_routes())
    end
  end

  def monitoring_live_view do
    quote do
      use Phoenix.LiveView,
        layout: {HolterWeb.Layouts, :app}

      on_mount HolterWeb.ObservabilityHook

      unquote(html_helpers())

      import HolterWeb.Timezone, only: [format_datetime: 2, short_cause: 1]
      import HolterWeb.Components.Monitoring.DashboardHeader
      import HolterWeb.Components.Monitoring.MonitorCard
      import HolterWeb.Components.Monitoring.HealthBadge
      import HolterWeb.Components.Monitoring.StatusPill
      import HolterWeb.Components.Monitoring.Sparkline
      import HolterWeb.Components.Monitoring.DailyMetricsSection
      import HolterWeb.Components.Monitoring.MonitorFormFields
      import HolterWeb.Components.Monitoring.MonitorSnapshot
      import HolterWeb.Components.Monitoring.MonitorOverviewChart
      import HolterWeb.Components.Monitoring.LogsScatterChart
      import HolterWeb.Components.Monitoring.DailyMetricsChart
      import HolterWeb.Components.Monitoring.MonitorSubnav
      import HolterWeb.Components.Monitoring.IncidentGanttChart
    end
  end

  def workspace_live_view do
    quote do
      use Phoenix.LiveView,
        layout: {HolterWeb.Layouts, :workspace}

      on_mount HolterWeb.ObservabilityHook

      unquote(html_helpers())
    end
  end

  def delivery_live_view do
    quote do
      use Phoenix.LiveView,
        layout: {HolterWeb.Layouts, :app}

      on_mount HolterWeb.ObservabilityHook

      unquote(html_helpers())

      import HolterWeb.Components.Delivery.NotificationChannelFormFields
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: HolterWeb.Endpoint,
        router: HolterWeb.Router,
        statics: HolterWeb.static_paths()
    end
  end

  defp html_helpers do
    quote do
      import Phoenix.HTML
      import Phoenix.HTML.Form
      import Phoenix.Component

      import HolterWeb.Components.Flash
      import HolterWeb.Components.Button
      import HolterWeb.Components.Input
      import HolterWeb.Components.Header
      import HolterWeb.Components.Table
      import HolterWeb.Components.List
      import HolterWeb.Components.Modal
      import HolterWeb.Components.Tooltip
      import HolterWeb.Components.Icon
      import HolterWeb.Components.BackLink
      import HolterWeb.Components.Pagination
      import HolterWeb.Components.EmptyState
      import HolterWeb.Components.PageContainer

      use Gettext, backend: HolterWeb.Gettext

      alias Phoenix.LiveView.JS

      unquote(verified_routes())
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
