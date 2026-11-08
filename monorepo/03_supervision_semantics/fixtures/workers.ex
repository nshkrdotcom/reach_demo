defmodule ReachDemo.Supervision.WorkerA do
  use GenServer
  def start_link(arg), do: GenServer.start_link(__MODULE__, arg)
  @impl true
  def init(arg), do: {:ok, arg}
end

defmodule ReachDemo.Supervision.WorkerB do
  use GenServer
  def start_link(arg), do: GenServer.start_link(__MODULE__, arg)
  @impl true
  def init(arg), do: {:ok, arg}
end
