defmodule ReachDemo.PluginSDGs.DependencyOnlyMix do
  def project do
    [app: :inert_dep_fixture, version: "0.0.1", deps: [{:ecto, "~> 3.0"}]]
  end
end
