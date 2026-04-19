defmodule HolterWeb.Router do
  use HolterWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug HolterWeb.Plugs.SessionMetadataPlug
    plug :fetch_live_flash
    plug :put_root_layout, html: {HolterWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :browser_api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug HolterWeb.Plugs.SessionMetadataPlug
    plug :protect_from_forgery
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug HolterWeb.Plugs.SessionMetadataPlug
    plug OpenApiSpex.Plug.PutApiSpec, otp_app: :holter, module: HolterWeb.Api.ApiSpec
  end

  scope "/api/v1", HolterWeb.Api do
    pipe_through :browser_api
    post "/telemetry/logs", TelemetryController, :log
  end

  scope "/api/v1", HolterWeb.Api do
    pipe_through :api

    scope "/workspaces/:workspace_slug" do
      get "/", WorkspaceController, :show
      resources "/monitors", MonitorController, only: [:index, :create]
    end

    resources "/monitors", MonitorController, except: [:index, :create, :new, :edit]

    scope "/monitors/:monitor_id" do
      resources "/logs", MonitorLogController, only: [:index, :show]
      resources "/daily_metrics", DailyMetricController, only: [:index]
      resources "/incidents", IncidentController, only: [:index]
    end
  end

  scope "/monitoring/workspaces/:workspace_slug", HolterWeb.Web.Monitoring do
    pipe_through :browser

    live "/dashboard", MonitorLive.Index, :index
    live "/monitor/new", MonitorLive.New, :new
  end

  scope "/monitoring", HolterWeb.Web.Monitoring do
    pipe_through :browser

    live "/monitor/:id", MonitorLive.Show, :show
    live "/monitor/:id/logs", MonitorLive.Logs, :index
    live "/monitor/:id/daily_metrics", MonitorLive.DailyMetrics, :index
    live "/monitor/:id/incidents", MonitorLive.Incidents, :index
    live "/incidents/:incident_id", MonitorLive.IncidentDetail, :show
    live "/logs/:log_id", MonitorLive.LogDetail, :show
  end

  if Application.compile_env(:holter, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: HolterWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end

    scope "/api" do
      pipe_through :api
      get "/openapi", OpenApiSpex.Plug.RenderSpec, []
    end

    scope "/" do
      pipe_through :browser
      get "/api/swagger", OpenApiSpex.Plug.SwaggerUI, path: "/api/openapi"
    end
  end
end
