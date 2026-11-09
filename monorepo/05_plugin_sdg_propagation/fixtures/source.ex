defmodule ReachDemo.PluginSDGs.Target do
  def origin(input), do: {:origin, input}
  def destination(input), do: {:destination, input}
end
