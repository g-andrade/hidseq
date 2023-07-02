defmodule HidSeq.MixProject do
  use Mix.Project

  def project do
    [
      app: :hidseq,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
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
      extra_applications: [
        :crypto,
        # TODO review
        :logger
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev], runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev], runtime: false},
      {:fpe, github: "g-andrade/elixir-fpe", branch: "main"}, # FIXME
      {:recon, "~> 2.3", only: [:dev], runtime: false}
    ]
  end
end
