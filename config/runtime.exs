import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/holter start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :holter, HolterWeb.Endpoint, server: true
end

integrations_vault_key = System.get_env("INTEGRATIONS_VAULT_KEY")

if config_env() in [:prod, :staging] and
     (is_nil(integrations_vault_key) or integrations_vault_key == "") do
  raise """
  environment variable INTEGRATIONS_VAULT_KEY is missing.
  Generate one with: :crypto.strong_rand_bytes(32) |> Base.encode64() |> IO.puts()
  This key encrypts OAuth credentials for all integrations.
  """
end

if integrations_vault_key do
  config :holter, Holter.Integrations.Vault,
    ciphers: [
      default:
        {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: Base.decode64!(integrations_vault_key)}
    ]
end

identity_pepper = System.get_env("IDENTITY_PEPPER")

if config_env() in [:prod, :staging] and (is_nil(identity_pepper) or identity_pepper == "") do
  raise """
  environment variable IDENTITY_PEPPER is missing.
  Generate one with: mix phx.gen.secret 64
  This pepper is mixed into every password hash; rotating it invalidates all stored passwords.
  """
end

if identity_pepper do
  config :holter, :identity, pepper: identity_pepper
end

delivery_alert_from_email = System.get_env("DELIVERY_ALERT_FROM_EMAIL")

if config_env() in [:prod, :staging] and
     (is_nil(delivery_alert_from_email) or delivery_alert_from_email == "") do
  raise """
  environment variable DELIVERY_ALERT_FROM_EMAIL is missing.
  Set it to the address that appears in the From: header of alert emails,
  e.g. noreply@alerts.yourdomain.com.
  """
end

if delivery_alert_from_email do
  config :holter, :email, from_address: delivery_alert_from_email
end

info_from_email = System.get_env("INFO_FROM_EMAIL")

if config_env() in [:prod, :staging] and (is_nil(info_from_email) or info_from_email == "") do
  raise """
  environment variable INFO_FROM_EMAIL is missing.
  Set it to the address that appears in the From: header of transactional
  emails (verification, recipient confirmation, etc.).
  """
end

if info_from_email do
  config :holter, :info_email, from_address: info_from_email
end

if System.get_env("ALERT_SMTP_HOST") do
  config :holter, Holter.Mailers.AlertMailer,
    adapter: Swoosh.Adapters.SMTP,
    relay: System.get_env("ALERT_SMTP_HOST"),
    port: String.to_integer(System.get_env("ALERT_SMTP_PORT", "587")),
    username: System.get_env("ALERT_SMTP_USERNAME"),
    password: System.get_env("ALERT_SMTP_PASSWORD"),
    tls: :always,
    auth: :always
end

if System.get_env("INFO_SMTP_HOST") do
  config :holter, Holter.Mailers.InfoMailer,
    adapter: Swoosh.Adapters.SMTP,
    relay: System.get_env("INFO_SMTP_HOST"),
    port: String.to_integer(System.get_env("INFO_SMTP_PORT", "587")),
    username: System.get_env("INFO_SMTP_USERNAME"),
    password: System.get_env("INFO_SMTP_PASSWORD"),
    tls: :always,
    auth: :always
end

config :holter, HolterWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() in [:prod, :staging] do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :holter, Holter.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :holter, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :holter, HolterWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:OPTIONS/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :holter, HolterWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :holter, HolterWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :holter, Holter.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end

google_ads_client_id = System.get_env("GOOGLE_ADS_CLIENT_ID")
google_ads_client_secret = System.get_env("GOOGLE_ADS_CLIENT_SECRET")
google_ads_developer_token = System.get_env("GOOGLE_ADS_DEVELOPER_TOKEN")
google_ads_redirect_uri = System.get_env("GOOGLE_ADS_REDIRECT_URI")

google_ads_vars = [
  google_ads_client_id,
  google_ads_client_secret,
  google_ads_developer_token,
  google_ads_redirect_uri
]

if config_env() in [:prod, :staging] and Enum.any?(google_ads_vars) and
     not Enum.all?(google_ads_vars) do
  raise """
  Partial Google Ads configuration detected — all or none must be set.
  Required: GOOGLE_ADS_CLIENT_ID, GOOGLE_ADS_CLIENT_SECRET,
            GOOGLE_ADS_DEVELOPER_TOKEN, GOOGLE_ADS_REDIRECT_URI
  """
end

if google_ads_api_version = System.get_env("GOOGLE_ADS_API_VERSION") do
  config :holter, :google_ads, api_version: google_ads_api_version
end

if google_ads_redirect_uri do
  config :holter, :google_ads, redirect_uri: google_ads_redirect_uri
end

if google_ads_client_id do
  config :holter, :google_ads,
    client_id: google_ads_client_id,
    client_secret: google_ads_client_secret,
    developer_token: google_ads_developer_token
end

meta_ads_app_id = System.get_env("META_ADS_APP_ID")
meta_ads_app_secret = System.get_env("META_ADS_APP_SECRET")
meta_ads_redirect_uri = System.get_env("META_ADS_REDIRECT_URI")

meta_ads_vars = [meta_ads_app_id, meta_ads_app_secret, meta_ads_redirect_uri]

if config_env() in [:prod, :staging] and Enum.any?(meta_ads_vars) and
     not Enum.all?(meta_ads_vars) do
  raise """
  Partial Meta Ads configuration detected — all or none must be set.
  Required: META_ADS_APP_ID, META_ADS_APP_SECRET, META_ADS_REDIRECT_URI
  """
end

if meta_ads_api_version = System.get_env("META_ADS_API_VERSION") do
  config :holter, :meta_ads, api_version: meta_ads_api_version
end

if meta_ads_redirect_uri do
  config :holter, :meta_ads, redirect_uri: meta_ads_redirect_uri
end

if meta_ads_app_id do
  config :holter, :meta_ads,
    app_id: meta_ads_app_id,
    app_secret: meta_ads_app_secret
end

if System.get_env("SENTRY_DSN") do
  config :sentry,
    dsn: System.get_env("SENTRY_DSN"),
    environment_name: config_env(),
    enable_source_code_context: true,
    root_source_code_paths: [File.cwd!()],
    tags: %{env: config_env()},
    traces_sample_rate: String.to_float(System.get_env("SENTRY_TRACES_SAMPLE_RATE") || "0.1")
end
