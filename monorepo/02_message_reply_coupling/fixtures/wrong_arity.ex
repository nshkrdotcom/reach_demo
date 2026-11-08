defmodule ReachDemo.Messages.ActualServer do
  use GenServer
  @impl true
  def init(state), do: {:ok, state}
  @impl true
  def handle_call({:lookup, key}, _from, state), do: {:reply, {:real, key}, state}
end

defmodule ReachDemo.Messages.NotACallback do
  def handle_call(value), do: {:reply, {:decoy, value}, :unused}
end

defmodule ReachDemo.Messages.WrongArityCaller do
  def lookup(key), do: GenServer.call(ReachDemo.Messages.ActualServer, {:lookup, key})
end
