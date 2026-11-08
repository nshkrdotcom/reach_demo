defmodule ReachDemo.Supervision.StrategyRestForOne do
  use Supervisor
  def start_link(arg), do: Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  @impl true
  def init(_arg) do
    children = [ReachDemo.Supervision.WorkerA, ReachDemo.Supervision.WorkerB]
    Supervisor.init(children, strategy: :rest_for_one)
  end
end
