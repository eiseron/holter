import Config

config :holter,
  ecto_repos: [Holter.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true],
  monitor_client: Holter.Monitoring.MonitorClient.HTTP,
  network_resolver: Holter.Network.Resolver.Erlang

config :holter, HolterWeb.Gettext, default_locale: "pt_BR"

config :holter, HolterWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: HolterWeb.Web.ErrorHTML, json: HolterWeb.Api.ErrorJSON],
    layout: false
  ],
  pubsub_server: Holter.PubSub,
  live_view: [signing_salt: "W9N2oSh5"]

config :holter, Holter.Mailers.AlertMailer, adapter: Swoosh.Adapters.Local
config :holter, Holter.Mailers.InfoMailer, adapter: Swoosh.Adapters.Local

config :holter, :email, from_address: "noreply@alerts.holter.dev"
config :holter, :info_email, from_address: "noreply@holter.dev"

config :holter, :identity,
  pepper: nil,
  session_max_age_seconds: 60 * 60 * 24 * 30,
  verify_email_token_max_age_seconds: 60 * 60

config :argon2_elixir, argon2_type: 2

config :esbuild,
  version: "0.25.4",
  holter: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# --- MODER LOGGING CONFIGURATION ---
# Configure the modern handler system (Elixir 1.15+)
config :logger, :default_handler,
  formatter: {Holter.Observability.LoggerFormatter, metadata: :all}

# Configuration for legacy tools that might still read this
config :logger, :console,
  format: "$message\n",
  metadata: [
    :request_id,
    :session_id,
    :workspace_id,
    :monitor_id,
    :job_id,
    :job_worker,
    :job_queue,
    :context,
    :user_agent,
    :node,
    :hostname,
    :holter_version,
    :otp_version,
    :elixir_version,
    :phoenix_version
  ]

# -----------------------------------

config :sentry,
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()]

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :phoenix, :json_library, Jason

config :holter, :api_specs, [
  {HolterWeb.Api.MonitoringApiSpec, "docs/api/monitoring.yml"},
  {HolterWeb.Api.DeliveryApiSpec, "docs/api/delivery.yml"},
  {HolterWeb.Api.ApiSpec, "docs/api/openapi.yml"}
]

config :holter, Oban,
  repo: Holter.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 90},
    {Oban.Plugins.Cron,
     crontab: [
       {"* * * * *", Holter.Monitoring.Workers.MonitorDispatcher},
       {System.get_env("METRICS_CRON_SCHEDULE", "0 7 * * *"),
        Holter.Monitoring.Workers.DailyMetricsAggregator}
     ]}
  ],
  queues: [dispatchers: 1, checks: 50, metrics: 5, notifications: 10]

import_config "#{config_env()}.exs"
