defmodule EventStore.Mixfile do
  use Mix.Project

  @version File.read!("VERSION") |> String.strip

  def project do
    [
      app: :eventstore,
      version: @version,
      elixir: "~> 1.0",
      description: "HTTP Client for EventStore (geteventstore.com)",
      deps: deps,
      package: package,
      consolidate_protocols: Mix.env != :test
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:httpoison, :logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:httpoison, "~> 0.8"},
      {:poison, "~> 2.1"},
      {:uuid, "~> 1.1"},
    ]
  end

  defp package do
    [
      files: ~w(lib mix.exs README.md VERSION),
      maintainers: ["Henrik Tudborg <henriktudborg@gmail.com>"],
      licenses: [],
      links: %{
        "GitHub" => "https://github.com/tbug/elixir-eventstore-http-client"
      }
    ]
  end
end
