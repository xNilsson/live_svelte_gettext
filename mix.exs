defmodule LiveSvelteGettext.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/xnilsson/live_svelte_gettext"

  def project do
    [
      app: :live_svelte_gettext,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex package metadata
      description: "Zero-maintenance i18n for Phoenix + Svelte using compile-time extraction",
      package: package(),

      # Documentation
      name: "LiveSvelteGettext",
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
      {:phoenix_live_view, "~> 1.0", optional: true},

      # Development dependencies
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp package do
    [
      name: "live_svelte_gettext",
      files: ~w(
        lib
        priv
        assets/package
        .formatter.exs
        mix.exs
        README.md
        LICENSE
        CHANGELOG.md
      ),
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
          LiveSvelteGettext,
          LiveSvelteGettext.Components
        ],
        Internal: [
          LiveSvelteGettext.Extractor,
          LiveSvelteGettext.Compiler
        ],
        Tasks: [
          Mix.Tasks.LiveSvelteGettext.Install
        ]
      ],
      groups_for_extras: [
        "Getting Started": ["README.md"],
        "Project Info": ["CHANGELOG.md", "LICENSE"]
      ],
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end
end
