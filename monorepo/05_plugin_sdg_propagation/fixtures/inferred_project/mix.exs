# An inert target-project dependency declaration: Reach's inference should read,
# not evaluate, this mix.exs. This is deliberately not the running Mix project.
defmodule ReachDemo.PluginSDGs.InferredProject do
  def project do
    [app: :target_fixture, version: "0.0.1", deps: [{:ecto, "~> 3.0"}]]
  end
end
