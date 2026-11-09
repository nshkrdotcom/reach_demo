defmodule ReachDemo.GenStatem.PostponeTimeout do
  @behaviour :gen_statem

  def callback_mode(), do: :handle_event_function
  def init(_opts), do: {:ok, :idle, %{}}

  def handle_event(:cast, :wait, :idle, data),
    do: {:keep_state, data, [:postpone, {:state_timeout, 500, :wake}]}

  def handle_event(:state_timeout, :wake, :idle, data),
    do: {:next_state, :active, data, [{{:timeout, :named}, 100, :expire}]}

  def handle_event({:timeout, :named}, :expire, :active, data),
    do: {:next_state, :idle, data}

  def handle_event(_type, _event, _state, data), do: {:keep_state, data}
end
