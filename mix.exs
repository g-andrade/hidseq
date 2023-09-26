defmodule HidSeq.MixProject do
  use Mix.Project

  def project do
    [
      app: :hidseq,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: elixirc_options(Mix.env()),
      test_coverage: [
        summary: [
          # FIXME
          threshold: 0
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: []
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev], runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev], runtime: false},
      # FIXME
      {:ff3_1, github: "g-andrade/elixir-ff3-1", ref: "1ef8354"},
      {:recon, "~> 2.3", only: [:dev], runtime: false},
      {:styler, "~> 0.9", only: [:dev, :test], runtime: false}
    ]
  end

  defp elixirc_paths(env) do
    if env == :test do
      ["lib", "test/helper"]
    else
      ["lib"]
    end
  end

  defp elixirc_options(env) do
    if env in [:dev, :test] do
      [{:warnings_as_errors, true}]
    else
      []
    end
  end
end
