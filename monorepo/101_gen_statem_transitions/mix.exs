defmodule ReachDemo.Project101.MixProject do
  use Mix.Project

  def project do
    [
      app: :reach_demo_gen_statem,
      version: "0.1.0",
      elixir: ">= 1.18.0",
      start_permanent: Mix.env() == :prod,
      deps: [{:reach, "== 2.8.4"}]
    ]
  end

  def application, do: [extra_applications: [:logger, :crypto]]
end
