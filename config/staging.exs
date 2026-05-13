import Config

import_config "prod.exs"

config :holter, HolterWeb.Endpoint, debug_errors: true

config :logger, level: :debug
