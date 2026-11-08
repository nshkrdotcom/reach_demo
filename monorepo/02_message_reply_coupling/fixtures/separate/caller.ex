defmodule ReachDemo.Messages.Caller do
  def lookup(key), do: GenServer.call(ReachDemo.Messages.ServerA, {:lookup, key})
end
