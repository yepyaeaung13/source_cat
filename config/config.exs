# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :phoenix, :filter_parameters, ["password", "secret", "current_secret", "token"]

config :ash, default_string_length_count: :codepoints

config :ash_typescript,
  manifest: SourceCat.AshTypescriptManifest,
  output_file: "assets/js/ash_rpc.ts",
  run_endpoint: "/rpc/run",
  validate_endpoint: "/rpc/validate",
  input_field_formatter: :camel_case,
  output_field_formatter: :camel_case,
  require_tenant_parameters: false,
  generate_zod_schemas: false,
  generate_phx_channel_rpc_actions: false,
  generate_validation_functions: true,
  zod_import_path: "zod",
  zod_schema_suffix: "ZodSchema",
  generate_valibot_schemas: false,
  valibot_import_path: "valibot",
  valibot_schema_suffix: "ValibotSchema",
  phoenix_import_path: "phoenix"

config :source_cat,
  ash_domains: [SourceCat.Content, SourceCat.Accounts, SourceCat.Community],
  ecto_repos: [SourceCat.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :source_cat, SourceCatWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: SourceCatWeb.ErrorHTML, json: SourceCatWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: SourceCat.PubSub,
  live_view: [signing_salt: "mIXg1Uwm"]

# Configure LiveView
config :phoenix_live_view,
  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
  root_tag_attribute: "phx-r"

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :source_cat, SourceCat.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  source_cat: [
    args:
      ~w(js/index.tsx js/app.js --bundle --target=es2022 --outdir=../priv/static/assets --external:/fonts/* --external:/images/* --alias:@=. --splitting --format=esm),
    cd: Path.expand("../assets", __DIR__),
    env: %{
      "NODE_PATH" =>
        Enum.join(
          [
            Path.expand("../deps", __DIR__),
            Path.expand(Mix.Project.build_path()),
            Path.expand("../_build/dev", __DIR__)
          ],
          ":"
        )
    }
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.3",
  source_cat: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__),
    env: %{
      "NODE_PATH" =>
        Enum.join(
          [
            Path.expand("../deps", __DIR__),
            Path.expand(Mix.Project.build_path()),
            Path.expand("../_build/dev", __DIR__)
          ],
          ":"
        )
    }
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
