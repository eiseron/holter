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

  get "/healthz", HolterWeb.HealthController, :show

  scope "/", HolterWeb.Web do
    pipe_through :browser

    get "/", RootController, :show
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
      resources "/webhook_channels", WebhookChannelController, only: [:index, :create]
      resources "/email_channels", EmailChannelController, only: [:index, :create]
    end

    resources "/webhook_channels", WebhookChannelController, only: [:show, :update, :delete] do
      post "/pings", WebhookChannelController, :ping
      put "/signing_token", WebhookChannelController, :rotate_signing_token
      resources "/delivery_logs", DeliveryLogController, only: [:index]
    end

    resources "/email_channels", EmailChannelController, only: [:show, :update, :delete] do
      post "/pings", EmailChannelController, :ping
      put "/anti_phishing_code", EmailChannelController, :rotate_anti_phishing_code
      resources "/delivery_logs", DeliveryLogController, only: [:index]
    end
  end

  scope "/identity", HolterWeb.Web.Identity do
    pipe_through :browser

    live_session :guest_identity,
      on_mount: [{HolterWeb.Hooks.UserAuthHook, :redirect_if_authenticated}] do
      live "/new", UserRegistrationLive, :new
      live "/login", UserLoginLive, :new
    end

    post "/login", UserSessionController, :create
    delete "/logout", UserSessionController, :delete

    live_session :public_identity,
      on_mount: [{HolterWeb.Hooks.UserAuthHook, :assign_current_user}] do
      live "/verify-email/:token", UserEmailVerificationLive, :verify
    end
  end

  scope "/delivery/workspaces/:workspace_slug", HolterWeb.Web.Delivery do
    pipe_through :browser

    live_session :authenticated_delivery_workspace,
      on_mount: [
        {HolterWeb.Hooks.UserAuthHook, :require_authenticated},
        {HolterWeb.Hooks.UserAuthHook, :require_workspace_member}
      ] do
      live "/channels", ChannelsLive, :index
      live "/channels/new", ChannelsLive.New, :new
      live "/webhook-channels/new", WebhookChannelLive.New, :new
      live "/email-channels/new", EmailChannelLive.New, :new
    end
  end

  scope "/delivery", HolterWeb.Web.Delivery do
    pipe_through :browser

    live_session :public_delivery_verify,
      on_mount: [{HolterWeb.Hooks.UserAuthHook, :assign_current_user}] do
      live "/email-channels/recipients/verify/:token",
           EmailChannelRecipientLive.Verify,
           :verify

      live "/email-channels/verify/:token",
           EmailChannelLive.Verify,
           :verify
    end

    live_session :authenticated_webhook_channel,
      on_mount: [
        {HolterWeb.Hooks.UserAuthHook, :require_authenticated},
        {HolterWeb.Hooks.UserAuthHook, :require_webhook_channel_member}
      ] do
      live "/webhook-channels/:id", WebhookChannelLive.Show, :show
      live "/webhook-channels/:id/logs", WebhookChannelLive.Logs, :index
    end

    live_session :authenticated_email_channel,
      on_mount: [
        {HolterWeb.Hooks.UserAuthHook, :require_authenticated},
        {HolterWeb.Hooks.UserAuthHook, :require_email_channel_member}
      ] do
      live "/email-channels/:id", EmailChannelLive.Show, :show
      live "/email-channels/:id/logs", EmailChannelLive.Logs, :index
    end
  end

  scope "/monitoring/workspaces/:workspace_slug", HolterWeb.Web.Monitoring do
    pipe_through :browser

    live_session :authenticated_monitoring_workspace,
      on_mount: [
        {HolterWeb.Hooks.UserAuthHook, :require_authenticated},
        {HolterWeb.Hooks.UserAuthHook, :require_workspace_member}
      ] do
      live "/monitor/new", MonitorLive.New, :new
      live "/monitors", MonitorsLive, :index
    end
  end

  scope "/monitoring", HolterWeb.Web.Monitoring do
    pipe_through :browser

    live_session :authenticated_monitor,
      on_mount: [
        {HolterWeb.Hooks.UserAuthHook, :require_authenticated},
        {HolterWeb.Hooks.UserAuthHook, :require_monitor_member}
      ] do
      live "/monitor/:id", MonitorLive.Show, :show
      live "/monitor/:id/logs", MonitorLive.Logs, :index
      live "/monitor/:id/daily_metrics", MonitorLive.DailyMetrics, :index
      live "/monitor/:id/incidents", MonitorLive.Incidents, :index
    end

    live_session :authenticated_incident,
      on_mount: [
        {HolterWeb.Hooks.UserAuthHook, :require_authenticated},
        {HolterWeb.Hooks.UserAuthHook, :require_incident_member}
      ] do
      live "/incidents/:incident_id", MonitorLive.IncidentDetail, :show
    end

    live_session :authenticated_log,
      on_mount: [
        {HolterWeb.Hooks.UserAuthHook, :require_authenticated},
        {HolterWeb.Hooks.UserAuthHook, :require_log_member}
      ] do
      live "/logs/:log_id", MonitorLive.LogDetail, :show
    end
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
