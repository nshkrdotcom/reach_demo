defmodule ReachDemo.Supervision.DirectLiteral do
  def start_link(_arg) do
    Supervisor.start_link(
      [ReachDemo.Supervision.WorkerA, ReachDemo.Supervision.WorkerB],
      strategy: :one_for_one,
      name: __MODULE__
    )
  end
end
