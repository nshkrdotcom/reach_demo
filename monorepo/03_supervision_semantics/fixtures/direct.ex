defmodule ReachDemo.Supervision.DirectSupervisor do
  def start_link(_arg) do
    children = [ReachDemo.Supervision.WorkerA, ReachDemo.Supervision.WorkerB]
    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end
end
