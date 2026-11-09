defmodule ReachDemo.Project06.MixProject do
  use Mix.Project

  def project do
    [
      app: :reach_demo_parse_diagnostics,
      version: "0.1.0",
      elixir: ">= 1.18.0",
      start_permanent: Mix.env() == :prod,
      deps: [{:reach, "== 2.8.4"}]
    ]
  end

  def application, do: [extra_applications: [:logger, :crypto, :ex_unit]]
end
