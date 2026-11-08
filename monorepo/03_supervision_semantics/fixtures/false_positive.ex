defmodule ReachDemo.Supervision.Foo do
  def init(value), do: value
end

defmodule ReachDemo.Supervision.NotASupervisor do
  use GenServer
  def start_link(arg), do: GenServer.start_link(__MODULE__, arg)
  @impl true
  def init(value) do
    ReachDemo.Supervision.Foo.init(value)
    {:ok, value}
  end
end
