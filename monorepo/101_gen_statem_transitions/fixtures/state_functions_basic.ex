defmodule ReachDemo.GenStatem.StateFunctionsBasic do
  @behaviour :gen_statem

  def callback_mode(), do: :state_functions
  def init(_opts), do: {:ok, :idle, %{count: 0}}

  def idle(:cast, :activate, data), do: {:next_state, :active, data}
  def idle(_event_type, _event, data), do: {:keep_state, data}
  def active(:cast, :reset, data), do: {:next_state, :idle, data}
  def active(_event_type, _event, data), do: {:keep_state, data}
end
