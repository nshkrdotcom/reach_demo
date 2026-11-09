defmodule ReachDemo.GenStatem.DynamicMode do
  @behaviour :gen_statem

  # No :state_functions or :handle_event_function literal occurs in this file.
  # A runtime-provided mode cannot be determined from this inert source alone.
  def callback_mode(), do: Application.fetch_env!(:reach_demo_gen_statem, :mode)
  def init(_opts), do: {:ok, :idle, %{}}

  def handle_event(:cast, :go, :idle, data), do: {:next_state, :active, data}
  def handle_event(_type, _event, _state, data), do: {:keep_state, data}
end
