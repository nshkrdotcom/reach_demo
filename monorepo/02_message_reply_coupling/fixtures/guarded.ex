defmodule ReachDemo.Messages.Guarded do
  use GenServer
  @impl true
  def init(state), do: {:ok, state}
  @impl true
  def handle_call({:lookup, key}, _from, state) when is_atom(key) do
    body_local = {:local, key}
    {:reply, body_local, state}
  end

  def lookup(key), do: GenServer.call(__MODULE__, {:lookup, key})
end
