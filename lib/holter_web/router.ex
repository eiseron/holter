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

    resources "/monitors", MonitorController, except: [:index, :create, :new, :edit] do
      resources "/logs", MonitorLogController, only: [:index, :show]
      resources "/daily_metrics", DailyMetricController, only: [:index]
      resources "/incidents", IncidentController, only: [:index]
    end

    resources "/incidents", IncidentController, only: [:show]

    scope "/workspaces/:workspace_slug" do
      resources "/notification_channels", NotificationChannelController, except: [:new, :edit]
    end

    resources "/notification_channels", NotificationChannelController, only: [] do
      post "/test", NotificationChannelController, :test
      resources "/logs", ChannelLogController, only: [:index]
    end
  end

  scope "/delivery/workspaces/:workspace_slug", HolterWeb.Web.Delivery do
    pipe_through :browser

    live "/channels", ChannelsLive, :index
    live "/notification-channels/new", NotificationChannelLive.New, :new
  end

  scope "/delivery", HolterWeb.Web.Delivery do
    pipe_through :browser

    live "/notification-channels/recipients/verify/:token",
         NotificationChannelRecipientLive.Verify,
         :verify

    live "/notification-channels/:id", NotificationChannelLive.Show, :show
    live "/notification-channels/:id/logs", NotificationChannelLive.Logs, :index
    live "/notification-channels/:id/logs/:log_id", NotificationChannelLive.LogDetail, :show
  end

  scope "/monitoring/workspaces/:workspace_slug", HolterWeb.Web.Monitoring do
    pipe_through :browser

    live "/monitor/new", MonitorLive.New, :new
    live "/monitors", MonitorsLive, :index
  end

  scope "/monitoring", HolterWeb.Web.Monitoring do
    pipe_through :browser

    scope "/monitor/:id" do
      live "/", MonitorLive.Show, :show
      live "/logs", MonitorLive.Logs, :index
      live "/daily_metrics", MonitorLive.DailyMetrics, :index
      live "/incidents", MonitorLive.Incidents, :index
    end

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
