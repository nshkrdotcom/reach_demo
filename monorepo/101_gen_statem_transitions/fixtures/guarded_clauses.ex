defmodule ReachDemo.GenStatem.GuardedClauses do
  @behaviour :gen_statem

  def callback_mode(), do: :handle_event_function
  def init(_opts), do: {:ok, :idle, %{}}

  def handle_event(:cast, {:advance, count}, :idle, data) when count > 0,
    do: {:next_state, :active, data}

  def handle_event(:cast, {:advance, count}, :idle, data) when count <= 0,
    do: {:keep_state, data}

  def handle_event(_type, _event, _state, data), do: {:keep_state, data}
end
