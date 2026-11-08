defmodule ReachDemo.Messages.ServerA do
  use GenServer
  def start_link(arg), do: GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  @impl true
  def init(arg), do: {:ok, arg}
  @impl true
  def handle_call({:lookup, key}, _from, state), do: {:reply, {:from_a, key}, state}
end

defmodule ReachDemo.Messages.ServerB do
  use GenServer
  def start_link(arg), do: GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  @impl true
  def init(arg), do: {:ok, arg}
  @impl true
  def handle_call({:lookup, key}, _from, state), do: {:reply, {:from_b, key}, state}
end

defmodule ReachDemo.Messages.Caller do
  def lookup(key), do: GenServer.call(ReachDemo.Messages.ServerA, {:lookup, key})
end
