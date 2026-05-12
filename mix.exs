defmodule WPL.Validator.MixProject do
  use Mix.Project

  @version "1.6.7"
  @source_url "https://github.com/gymbile/wpl-validator-ex"

  def project do
    [
      app: :wpl_validator,
      version: @version,
      elixir: "~> 1.15",
      description: description(),
      package: package(),
      deps: deps(),
      docs: docs(),
      source_url: @source_url,
      homepage_url: "https://wpl.dev",
      name: "WPL Validator",
      start_permanent: Mix.env() == :prod
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp description do
    "Reference Elixir validator for WPL (Wellness Plan Language) — JSON Schema + semantic invariants"
  end

  defp package do
    [
      maintainers: ["Gymbile"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "Schema" => "https://github.com/gymbile/wpl",
        "Spec" => "https://wpl.dev"
      },
      files: ~w(lib priv mix.exs README.md CHANGELOG.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "WPL.Validator",
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end

  defp deps do
    [
      {:ex_json_schema, "~> 0.11"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end
end
