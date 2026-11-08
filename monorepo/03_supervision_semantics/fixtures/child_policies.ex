defmodule ReachDemo.Supervision.ChildPolicies do
  use Supervisor
  def start_link(arg), do: Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  @impl true
  def init(_arg) do
    children = [
      Supervisor.child_spec(ReachDemo.Supervision.WorkerA,
        id: :permanent_a,
        restart: :permanent,
        shutdown: 3000,
        type: :worker
      ),
      Supervisor.child_spec(ReachDemo.Supervision.WorkerB,
        id: :transient_b,
        restart: :transient,
        shutdown: 5000,
        type: :worker
      ),
      Supervisor.child_spec({ReachDemo.Supervision.WorkerA, :short_lived},
        id: :temporary_c,
        restart: :temporary,
        shutdown: :brutal_kill,
        type: :worker
      )
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
