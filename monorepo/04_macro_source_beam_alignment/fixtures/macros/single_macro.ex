defmodule ReachDemo.MacroAlign.SingleGenerated do
  require ReachDemo.MacroAlign.Generator
  ReachDemo.MacroAlign.Generator.def_generated(:single_generated, :one)
  def explicit_function(), do: :authored
end
