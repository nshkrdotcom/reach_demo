defmodule ReachDemo.PluginSDGs.DependencyOnlySource do
  def identity(value), do: {:ok, value}
end
