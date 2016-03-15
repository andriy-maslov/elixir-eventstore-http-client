use Mix.Config


config :logger, level: :debug


config :eventstore_client, :options,
  url: "http://admin:changeit@192.168.99.100:2113"
