defmodule ReachDemo.NodeIDs.Example do
  def unrelated(value), do: {:new, value}
  def target(value), do: value + 1
end
