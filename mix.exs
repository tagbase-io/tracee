defmodule Tracee.MixProject do
  use Mix.Project

  @version "0.2.0"

  def project do
    [
      app: :tracee,
      version: @version,
      elixir: "~> 1.16",
      deps: deps(),
      name: "Tracee",
      description: "Trace function calls in concurrent Elixir processes.",

      # Package
      package: %{
        licenses: ["MIT"],
        maintainers: ["Mario Uher"],
        links: %{"GitHub" => "https://github.com/tagbase-io/tracee"}
      },

      # Docs
      docs: [
        source_url: "https://github.com/tagbase-io/tracee",
        main: "Tracee"
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :runtime_tools],
      mod: {Tracee.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.32.1", only: [:dev, :test]},
      {:markdown_formatter, "~> 0.6", only: [:dev, :test], runtime: false},
      {:styler, "~> 0.11.9", only: [:dev, :test], runtime: false}
    ]
  end
end
