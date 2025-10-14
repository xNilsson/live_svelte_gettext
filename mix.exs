defmodule LiveSvelteGettext.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/xnilsson/livesvelte_gettext"

  def project do
    [
      app: :livesvelte_gettext,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex package metadata
      description: "Zero-maintenance i18n for Phoenix + Svelte using compile-time extraction",
      package: package(),

      # Documentation
      name: "LiveSvelte Gettext",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),

      # Testing
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # Core dependencies
      {:gettext, "~> 0.24"},
      {:jason, "~> 1.4"},

      # Optional dependencies
      {:igniter, "~> 0.2", optional: true},

      # Development dependencies
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp package do
    [
      name: "livesvelte_gettext",
      files: ~w(lib priv assets .formatter.exs mix.exs README.md LICENSE CHANGELOG.md),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      maintainers: ["Christopher Nilsson"]
    ]
  end

  defp docs do
    [
      main: "LiveSvelteGettext",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: [
        "README.md",
        "CHANGELOG.md",
        "LICENSE"
      ],
      groups_for_modules: [
        Core: [
          LiveSvelteGettext
        ],
        Internal: [
          LiveSvelteGettext.Extractor,
          LiveSvelteGettext.Compiler,
          LiveSvelteGettext.Runtime
        ]
      ]
    ]
  end
end
