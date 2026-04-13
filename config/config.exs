# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :holter,
  ecto_repos: [Holter.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true],
  monitor_client: Holter.Monitoring.MonitorClient.HTTP

# Configure Gettext default locale
config :holter, HolterWeb.Gettext, default_locale: "pt_BR"

# Configure the endpoint
config :holter, HolterWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: HolterWeb.Web.ErrorHTML, json: HolterWeb.Api.ErrorJSON],
    layout: false
  ],
  pubsub_server: Holter.PubSub,
  live_view: [signing_salt: "W9N2oSh5"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :holter, Holter.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  holter: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure Elixir's Logger
config :logger, :default_handler,
  formatter: {Holter.Observability.LoggerFormatter, metadata: :all}

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [
    :request_id,
    :session_id,
    :workspace_id,
    :monitor_id,
    :context,
    :holter_version,
    :phoenix_version
  ]

config :sentry,
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure Oban
config :holter, Oban,
  repo: Holter.Repo,
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron,
     crontab: [
       {"* * * * *", Holter.Monitoring.Workers.MonitorDispatcher},
       {System.get_env("METRICS_CRON_SCHEDULE", "0 7 * * *"),
        Holter.Monitoring.Workers.DailyMetricsAggregator}
     ]}
  ],
  queues: [dispatchers: 1, checks: 50, metrics: 5]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
