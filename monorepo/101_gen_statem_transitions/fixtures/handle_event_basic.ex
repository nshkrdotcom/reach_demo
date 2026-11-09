defmodule ReachDemo.GenStatem.HandleEventBasic do
  @behaviour :gen_statem

  def callback_mode(), do: :handle_event_function
  def init(_opts), do: {:ok, :idle, %{}}

  def handle_event(:cast, :activate, :idle, data), do: {:next_state, :active, data}
  def handle_event(:cast, :reset, :active, data), do: {:next_state, :idle, data}
  def handle_event(_type, _event, _state, data), do: {:keep_state, data}
end
