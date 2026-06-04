defmodule HolterWeb.Router do
  use HolterWeb, :router

  @content_security_policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'self'; base-uri 'self'; form-action 'self'"

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug HolterWeb.Plugs.SessionMetadataPlug
    plug HolterWeb.Plugs.LocalePlug
    plug HolterWeb.Plugs.ImpersonationPlug
    plug :fetch_live_flash
    plug :put_root_layout, html: {HolterWeb.Layouts, :root}
    plug :protect_from_forgery

    plug :put_secure_browser_headers, %{"content-security-policy" => @content_security_policy}
  end

  pipeline :swagger_csp_nonce do
    plug :put_swagger_csp_nonce
  end

  pipeline :browser_api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug HolterWeb.Plugs.SessionMetadataPlug
    plug HolterWeb.Plugs.LocalePlug
    plug :protect_from_forgery
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug HolterWeb.Plugs.SessionMetadataPlug
    plug OpenApiSpex.Plug.PutApiSpec, otp_app: :holter, module: HolterWeb.Api.ApiSpec
    plug HolterWeb.Plugs.FetchApiBearerPlug
    plug HolterWeb.Plugs.RequireWorkspaceMemberPlug
  end

  pipeline :api_public do
    plug :accepts, ["json"]
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
      on_mount: [
        {HolterWeb.Hooks.UserAuthHook, :redirect_if_authenticated},
        HolterWeb.Hooks.LocaleHook
      ] do
      live "/new", UserRegistrationLive, :new
      live "/login", UserLoginLive, :new
      live "/forgot-password", UserForgotPasswordLive, :new
      live "/reset-password/:token", UserResetPasswordLive, :edit
    end

    post "/login", UserSessionController, :create
    delete "/logout", UserSessionController, :delete

    live_session :public_identity,
      on_mount: [
        {HolterWeb.Hooks.UserAuthHook, :assign_current_user},
        HolterWeb.Hooks.LocaleHook
      ] do
      live "/verify-email/:token", UserEmailVerificationLive, :verify
    end
  end

  scope "/identity", HolterWeb.Web.Identity do
    pipe_through :browser

    live_session :authenticated_user_settings,
      on_mount: [
        {HolterWeb.Hooks.UserAuthHook, :require_authenticated},
        {HolterWeb.Hooks.UserAuthHook, :require_self_user},
        HolterWeb.Hooks.LocaleHook
      ] do
      live "/user/:id", UserLive.Show, :show
    end
  end

  scope "/identity/workspaces/:workspace_slug", HolterWeb.Web.Workspaces do
    pipe_through :browser

    live_session :authenticated_workspace_settings,
      on_mount: [
        {HolterWeb.Hooks.UserAuthHook, :require_authenticated},
        {HolterWeb.Hooks.UserAuthHook, :require_workspace_admin},
        HolterWeb.Hooks.LocaleHook
      ] do
      live "/", ShowLive, :show
      live "/api-tokens", ApiTokensLive, :index
    end
  end

  scope "/admin", HolterWeb.Web.Admin do
    pipe_through :browser

    post "/users/:user_id/impersonation", ImpersonationController, :create
    delete "/impersonation", ImpersonationController, :delete

    live_session :authenticated_admin,
      on_mount: [
        {HolterWeb.Hooks.AdminAuthHook, :require_admin},
        HolterWeb.Hooks.LocaleHook
      ] do
      live "/", DashboardLive, :show
      live "/users", UsersLive, :index
      live "/users/:id", UsersLive.Show, :show
      live "/workspaces", WorkspacesLive, :index
      live "/workspaces/:id", WorkspacesLive.Show, :show
      live "/audit-log", AuditLogLive, :index
      live "/feature-flags", FeatureFlagsLive, :index
    end
  end

  scope "/delivery/workspaces/:workspace_slug", HolterWeb.Web.Delivery do
    pipe_through :browser

    live_session :authenticated_delivery_workspace,
      on_mount: [
        {HolterWeb.Hooks.UserAuthHook, :require_authenticated},
        {HolterWeb.Hooks.UserAuthHook, :require_workspace_member},
        HolterWeb.Hooks.LocaleHook
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
      on_mount: [
        {HolterWeb.Hooks.UserAuthHook, :assign_current_user},
        HolterWeb.Hooks.LocaleHook
      ] do
      live "/workspaces/:workspace_slug/email-channels/recipients/verify/:token",
           EmailChannelRecipientLive.Verify,
           :verify
    end

    live_session :authenticated_webhook_channel,
      on_mount: [
        {HolterWeb.Hooks.UserAuthHook, :require_authenticated},
        {HolterWeb.Hooks.UserAuthHook, :require_webhook_channel_member},
        HolterWeb.Hooks.LocaleHook
      ] do
      live "/webhook-channels/:id", WebhookChannelLive.Show, :show
      live "/webhook-channels/:id/logs", WebhookChannelLive.Logs, :index
    end

    live_session :authenticated_email_channel,
      on_mount: [
        {HolterWeb.Hooks.UserAuthHook, :require_authenticated},
        {HolterWeb.Hooks.UserAuthHook, :require_email_channel_member},
        HolterWeb.Hooks.LocaleHook
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
        {HolterWeb.Hooks.UserAuthHook, :require_workspace_member},
        HolterWeb.Hooks.LocaleHook
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
        {HolterWeb.Hooks.UserAuthHook, :require_monitor_member},
        HolterWeb.Hooks.LocaleHook
      ] do
      live "/monitor/:id", MonitorLive.Show, :show
      live "/monitor/:id/logs", MonitorLive.Logs, :index
      live "/monitor/:id/daily_metrics", MonitorLive.DailyMetrics, :index
      live "/monitor/:id/incidents", MonitorLive.Incidents, :index
    end

    live_session :authenticated_incident,
      on_mount: [
        {HolterWeb.Hooks.UserAuthHook, :require_authenticated},
        {HolterWeb.Hooks.UserAuthHook, :require_incident_member},
        HolterWeb.Hooks.LocaleHook
      ] do
      live "/incidents/:incident_id", MonitorLive.IncidentDetail, :show
    end

    live_session :authenticated_log,
      on_mount: [
        {HolterWeb.Hooks.UserAuthHook, :require_authenticated},
        {HolterWeb.Hooks.UserAuthHook, :require_log_member},
        HolterWeb.Hooks.LocaleHook
      ] do
      live "/logs/:log_id", MonitorLive.LogDetail, :show
    end
  end

  pipeline :browser_authenticated do
    plug :accepts, ["html"]
    plug :fetch_session
    plug HolterWeb.Plugs.SessionMetadataPlug
    plug HolterWeb.Plugs.LocalePlug
    plug :fetch_live_flash
    plug :put_root_layout, html: {HolterWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers, %{"content-security-policy" => @content_security_policy}
    plug HolterWeb.Plugs.FetchCurrentUserPlug
  end

  pipeline :integration_oauth_callback do
    plug HolterWeb.Plugs.IntegrationOAuthPlug
  end

  pipeline :integration_webhook_signature do
    plug HolterWeb.Plugs.IntegrationWebhookSignaturePlug
  end

  scope "/integrations/workspaces/:workspace_slug", HolterWeb.Web.Integrations do
    pipe_through :browser

    live_session :authenticated_integrations_workspace,
      on_mount: [
        {HolterWeb.Hooks.UserAuthHook, :require_authenticated},
        {HolterWeb.Hooks.UserAuthHook, :require_workspace_member},
        HolterWeb.Hooks.LocaleHook
      ] do
      live "/", IndexLive, :index
      live "/new", CatalogLive, :index
    end
  end

  scope "/integrations", HolterWeb.Web.Integrations do
    pipe_through :browser

    live_session :authenticated_integration,
      on_mount: [
        {HolterWeb.Hooks.UserAuthHook, :require_authenticated},
        {HolterWeb.Hooks.UserAuthHook, :require_integration_member},
        HolterWeb.Hooks.LocaleHook
      ] do
      live "/:id", ShowLive, :show
      live "/:id/logs", LogsLive, :show
    end
  end

  scope "/integrations/workspaces/:workspace_slug", HolterWeb.Web.Integrations do
    pipe_through :browser_authenticated

    get "/:provider/connect", IntegrationOAuthController, :connect
    delete "/:id", IntegrationOAuthController, :disconnect
  end

  scope "/integrations/workspaces/:workspace_slug", HolterWeb.Web.Integrations do
    pipe_through [:api_public, :integration_webhook_signature]

    post "/:provider/webhook", IntegrationWebhookController, :receive
  end

  scope "/integrations", HolterWeb.Web.Integrations do
    pipe_through [:browser_authenticated, :integration_oauth_callback]

    get "/:provider/callback", IntegrationOAuthController, :callback
  end

  scope "/api" do
    pipe_through :api_public
    get "/openapi", OpenApiSpex.Plug.RenderSpec, []
  end

  scope "/" do
    pipe_through [:browser, :swagger_csp_nonce]

    get "/api/swagger", OpenApiSpex.Plug.SwaggerUI,
      path: "/api/openapi",
      csp_nonce_assign_key: %{script: :script_src_nonce, style: :style_src_nonce},
      swagger_ui_css_url: "/vendor/swagger-ui/swagger-ui.css",
      swagger_ui_js_bundle_url: "/vendor/swagger-ui/swagger-ui-bundle.js",
      swagger_ui_js_standalone_preset_url: "/vendor/swagger-ui/swagger-ui-standalone-preset.js"
  end

  if Application.compile_env(:holter, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: HolterWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview

      live "/emails", HolterWeb.Web.Dev.EmailPreviewLive
      live "/emails/:preview_key/:variant_key", HolterWeb.Web.Dev.EmailPreviewLive
    end
  end

  defp put_swagger_csp_nonce(conn, _opts) do
    nonce = 16 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)

    csp =
      "default-src 'self'; " <>
        "script-src 'self' 'nonce-#{nonce}'; " <>
        "style-src 'self' 'unsafe-inline' 'nonce-#{nonce}'; " <>
        "img-src 'self' data:; connect-src 'self'; " <>
        "frame-ancestors 'self'; base-uri 'self'; form-action 'self'"

    conn
    |> Plug.Conn.assign(:script_src_nonce, nonce)
    |> Plug.Conn.assign(:style_src_nonce, nonce)
    |> Plug.Conn.put_resp_header("content-security-policy", csp)
  end
end
