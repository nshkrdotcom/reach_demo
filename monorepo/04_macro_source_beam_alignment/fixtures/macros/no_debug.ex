defmodule ReachDemo.MacroAlign.NoDebug do
  require ReachDemo.MacroAlign.Generator
  ReachDemo.MacroAlign.Generator.def_generated(:without_debug, :ok)
  def explicit_function(), do: :still_authored
end
