defmodule ReachDemo.Supervision.DirectNamed do
  def launch do
    Supervisor.start_link(
      [ReachDemo.Supervision.WorkerA, ReachDemo.Supervision.WorkerB],
      strategy: :one_for_one
    )
  end
end
