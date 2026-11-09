defmodule ReachDemo.GenStatem.StateEnterMode do
  @behaviour :gen_statem

  def callback_mode(), do: [:handle_event_function, :state_enter]
  def init(_opts), do: {:ok, :idle, %{}}

  def handle_event(:enter, _previous_state, :idle, data), do: {:keep_state, data}
  def handle_event(:cast, :activate, :idle, data), do: {:next_state, :active, data}
  def handle_event(:enter, _previous_state, :active, data), do: {:keep_state, data}
  def handle_event(_type, _event, _state, data), do: {:keep_state, data}
end
