defmodule ReachDemo.MacroAlign.TwoInvocations do
  require ReachDemo.MacroAlign.Generator
  ReachDemo.MacroAlign.Generator.def_generated(:alpha, :first)
  def between_invocations(), do: :authored

  ReachDemo.MacroAlign.Generator.def_generated(:beta, :second)
end
