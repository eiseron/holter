defmodule HolterWeb.Router do
  use HolterWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HolterWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug OpenApiSpex.Plug.PutApiSpec, otp_app: :holter, module: HolterWeb.Api.ApiSpec
  end

  scope "/", HolterWeb.Web do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/api/v1/workspaces/:workspace_slug", HolterWeb.Api do
    pipe_through :api

    resources "/monitors", MonitorController, except: [:new, :edit]
  end

  scope "/monitoring/workspaces/:workspace_slug", HolterWeb.Web.Monitoring do
    pipe_through :browser

    live "/dashboard", MonitorLive.Index, :index
    live "/monitor/new", MonitorLive.New, :new
    live "/monitor/:id", MonitorLive.Show, :show
    live "/monitor/:id/logs", MonitorLive.Logs, :index
  end

  if Application.compile_env(:holter, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: HolterWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end

    scope "/" do
      pipe_through :browser
      get "/api/openapi", OpenApiSpex.Plug.RenderSpec, []
      get "/api/swagger", OpenApiSpex.Plug.SwaggerUI, path: "/api/openapi"
    end
  end
end
