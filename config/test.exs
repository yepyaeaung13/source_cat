import Config

config :source_cat, maintenance_enabled: false

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :source_cat, SourceCat.Repo,
  database: Path.expand("../source_cat_test.db", __DIR__),
  # SQLite initialization and writes share one sandbox connection.
  pool_size: 1,
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :source_cat, SourceCatWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "7fhycmf+yGdH7M7f6dLrzz46jFEMxY/MVUDPzz7U+rbNNuS0PPVIZJyag4NliREx",
  server: false

# In test we don't send emails
config :source_cat, SourceCat.Mailer, adapter: Swoosh.Adapters.Test

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
