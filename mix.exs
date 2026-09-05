defmodule Plumbline.MixProject do
  use Mix.Project

  def project do
    [
      app: :plumbline,
      version: "0.1.0",
      # 1.18 is the floor: the notebook's assertion harness uses the
      # built-in JSON module, which landed in Elixir 1.18.
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        plt_local_path: "priv/plts",
        plt_core_path: "priv/plts",
        flags: [:error_handling, :extra_return, :missing_return, :underspecs]
      ],
      name: "Plumbline",
      description:
        "Proof-driven development: a Livebook that is simultaneously " <>
          "specification, test harness, curriculum, and documentation."
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # No RUNTIME dependencies, and worth keeping it that way.
  #
  # The propagator is pure arithmetic over floats and needs nothing but
  # :math. Visualisation dependencies (VegaLite, Kino) are pulled in by
  # the notebook's own Mix.install, not by the library. Everything below
  # is dev/test tooling with `runtime: false`, so the shipped
  # application still has an empty dependency graph.
  #
  # That keeps the offline cold-start rehearsal cheap and keeps the repo
  # readable in one sitting.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
