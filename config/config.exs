# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
import Config

# Latest version of timezone data (2019a) distributed by IANA has an error
# Disable the autoupdate until it is fixed
config :tzdata, :autoupdate, :disabled

# General application configuration
config :sanbase, ecto_repos: [Sanbase.Repo, Sanbase.TimescaleRepo]

config :phoenix, :json_library, Jason

config :ecto, json_library: Jason

config :sanbase, Sanbase,
  environment: "#{Mix.env()}",
  required_san_stake_full_access: {:system, "REQUIRED_SAN_STAKE_FULL_ACCESS", "1000"}

config :sanbase, Sanbase.ApiCallDataExporter,
  kafka_url: {:system, "KAFKA_URL", "blockchain-kafka-kafka"},
  kafka_port: {:system, "KAFKA_PORT", "9092"}

config :sanbase, Sanbase.ExternalServices.RateLimiting.Server,
  implementation_module: Sanbase.ExternalServices.RateLimiting.WaitServer

config :sanbase, Sanbase.ClickhouseRepo, adapter: Ecto.Adapters.Postgres

config :sanbase, Sanbase.Repo,
  loggers: [Ecto.LogEntry, Sanbase.Prometheus.EctoInstrumenter],
  adapter: Ecto.Adapters.Postgres,
  pool_size: {:system, "SANBASE_POOL_SIZE", "20"},
  max_overflow: 5,
  # because of pgbouncer
  prepare: :unnamed

config :sanbase, Sanbase.TimescaleRepo,
  loggers: [Ecto.LogEntry, Sanbase.Prometheus.EctoInstrumenter],
  adapter: Ecto.Adapters.Postgres,
  timeout: 30_000,
  pool_size: {:system, "TIMESCALE_POOL_SIZE", "30"},
  max_overflow: 5,
  # because of pgbouncer
  prepare: :unnamed

config :sanbase, Sanbase.Timescaledb,
  blockchain_schema: {:system, "TIMESCALEDB_BLOCKCHAIN_SCHEMA", "etherbi"}

config :sanbase, Sanbase.Auth.Hmac, secret_key: {:system, "APIKEY_HMAC_SECRET_KEY", nil}

# Configures the endpoint
config :sanbase, SanbaseWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Vq7Rfo0T4EfiLX2/ryYal3O0l9ebBNhyh58cfWdTAUHxEJGu2p9u1WTQ31Ki4Phj",
  render_errors: [view: SanbaseWeb.ErrorView, accepts: ~w(json)],
  pubsub: [name: Sanbase.PubSub, adapter: Phoenix.PubSub.PG2],
  # should be removed after app.santiment.net migration
  website_url: {:system, "WEBSITE_URL", "http://localhost:4000"},
  backend_url: {:system, "BACKEND_URL", "http://localhost:4000"},
  frontend_url: {:system, "FRONTEND_URL", "http://localhost:4000"}

# Do not log SASL crash reports
config :sasl, sasl_error_logger: false

# Configures Elixir's Logger
config :logger, :console,
  format: {Sanbase.Utils.JsonLogger, :format},
  metadata: [:request_id, :api_token, :user_id, :remote_ip, :complexity, :query, :san_balance],
  handle_otp_reports: true,
  handle_sasl_reports: true

# Error tracking
config :sentry,
  json_library: Jason,
  included_environments: [:prod],
  environment_name: Mix.env()

config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 4, cleanup_interval_ms: 60_000 * 10]}

config :xain, :after_callback, {Phoenix.HTML, :raw}

config :tesla, adapter: Tesla.Adapter.Hackney, recv_timeout: 30_000

config :sanbase, SanbaseWeb.Guardian,
  issuer: "santiment",
  secret_key: {SanbaseWeb.Guardian, :get_config, [:secret_key_base]}

config :sanbase, Sanbase.InternalServices.Ethauth,
  url: {:system, "ETHAUTH_URL"},
  basic_auth_username: {:system, "ETHAUTH_BASIC_AUTH_USERNAME"},
  basic_auth_password: {:system, "ETHAUTH_BASIC_AUTH_PASSWORD"}

config :sanbase, Sanbase.InternalServices.Parity,
  url: {:system, "PARITY_URL"},
  basic_auth_username: {:system, "PARITY_BASIC_AUTH_USERNAME"},
  basic_auth_password: {:system, "PARITY_BASIC_AUTH_PASSWORD"}

config :sanbase, SanbaseWeb.Graphql.ContextPlug,
  basic_auth_username: {:system, "GRAPHQL_BASIC_AUTH_USERNAME"},
  basic_auth_password: {:system, "GRAPHQL_BASIC_AUTH_PASSWORD"}

config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role],
  region: "eu-central-1"

config :sanbase, Sanbase.MandrillApi,
  apikey: {:system, "MANDRILL_APIKEY"},
  from_email: {:system, "MANDRILL_FROM_EMAIL", "admin@santiment.net"}

config :sanbase, Sanbase.TechIndicators, url: {:system, "TECH_INDICATORS_URL"}

config :arc,
  storage: Arc.Storage.S3,
  # To support AWS regions other than US Standard
  virtual_host: true,
  bucket: {:system, "POSTS_IMAGE_BUCKET"}

config :sanbase, Sanbase.Oauth2.Hydra,
  base_url: {:system, "HYDRA_BASE_URL", "http://localhost:4444"},
  token_uri: {:system, "HYDRA_TOKEN_URI", "/oauth2/token"},
  consent_uri: {:system, "HYDRA_CONSENT_URI", "/oauth2/consent/requests"},
  client_id: {:system, "HYDRA_CLIENT_ID", "consent-app"},
  client_secret: {:system, "HYDRA_CLIENT_SECRET", "consent-secret"},
  clients_that_require_san_tokens:
    {:system, "CLIENTS_THAT_REQUIRE_SAN_TOKENS", "{\"grafana\": 100}"}

config :sanbase, SanbaseWeb.Graphql.Middlewares.TimeframeRestriction,
  restrict_to_in_days: {:system, "RESTRICT_TO_IN_DAYS", "1"},
  restrict_from_in_days: {:system, "RESTRICT_FROM_IN_MONTHS", "90"}

config :sanbase, Sanbase.Discourse,
  url: {:system, "DISCOURSE_URL", "https://discourse.stage.internal.santiment.net/"},
  api_key: {:system, "DISCOURSE_API_KEY"},
  insights_category: {:system, "DISCOURSE_INSIGHTS_CATEGORY", "Sanbase Insights"}

config :libcluster,
  topologies: [
    k8s: [
      strategy: Elixir.Cluster.Strategy.Kubernetes,
      config: [
        mode: :dns,
        kubernetes_node_basename: "sanbase",
        kubernetes_selector: "app=sanbase",
        polling_interval: 10_000
      ]
    ]
  ]

config :sanbase, SanbaseWeb.Plug.SessionPlug,
  domain: {:system, "SANTIMENT_ROOT_DOMAIN", "localhost"}

config :sanbase, SanbaseWeb.Plug.BotLoginPlug,
  bot_login_endpoint: {:system, "BOT_LOGIN_SECRET_ENDPOINT"}

# Import configs
import_config "ex_admin_config.exs"
import_config "influxdb_config.exs"
import_config "scrapers_config.exs"
import_config "notifications_config.exs"
import_config "elasticsearch_config.exs"
import_config "prometheus_config.exs"
import_config "stripe_config.exs"
import_config "scheduler_config.exs"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
