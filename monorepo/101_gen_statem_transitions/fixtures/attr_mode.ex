defmodule ReachDemo.GenStatem.AttrMode do
  @behaviour :gen_statem
  @mode :handle_event_function
  def callback_mode(), do: @mode
  def init(_), do: {:ok, :idle, %{}}
  def handle_event(:cast, :go, :idle, data), do: {:next_state, :active, data}
  def handle_event(_t, _e, _s, data), do: {:keep_state, data}
end
