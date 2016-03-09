use Mix.Config


config :logger, level: :debug


config :eventstore_client, :options,
  host: "192.168.99.100",
  port: 2113
