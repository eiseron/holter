import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :holter, Holter.Repo,
  username: System.get_env("DB_USER"),
  password: System.get_env("DB_PASS"),
  hostname: System.get_env("DB_HOST"),
  database: "holter_test_#{System.get_env("DB_NAME")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :holter, HolterWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "H9ah5W2SFOFgHqIcLBfmmKfUfVWkuOc7Si0JjEuo5gk2kOdgiwaWCQtmfkFuljdg",
  server: false

# In test we don't send emails
config :holter, Holter.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Configure Oban in test mode
config :holter, Oban,
  repo: Holter.Repo,
  testing: :manual,
  queues: false,
  plugins: false

config :holter, dev_routes: true

config :holter, :sql_sandbox, true

config :holter, monitor_client: Holter.Monitoring.MonitorClientMock
config :holter, delivery_http_client: Holter.Delivery.HttpClientMock

# Set default locale to English for tests
config :holter, HolterWeb.Gettext, default_locale: "en"
