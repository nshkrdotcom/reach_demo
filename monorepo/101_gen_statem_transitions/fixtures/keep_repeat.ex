defmodule ReachDemo.GenStatem.KeepRepeat do
  @behaviour :gen_statem

  def callback_mode(), do: :state_functions
  def init(_opts), do: {:ok, :idle, %{}}

  def idle(:cast, :keep, data), do: {:keep_state, data}
  def idle(:cast, :repeat, data), do: {:repeat_state, data}
  def idle(:cast, :activate, data), do: {:next_state, :active, data}
  def idle(_type, _event, data), do: {:keep_state, data}
  def active(_type, _event, data), do: {:next_state, :idle, data}
end
