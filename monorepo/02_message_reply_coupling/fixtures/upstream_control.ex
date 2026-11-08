# Control adapted from Reach test/reach/otp/otp_test.exs (message content and call reply).
# The two isolated upstream examples are combined into one parseable source file.
defmodule MsgFlow do
  def notify(pid, data) do
    send(pid, {:update, data})
  end

  def handle_info({:update, payload}, state) do
    {:noreply, payload}
  end
end

defmodule ReplyFlow do
  def get_count(pid) do
    GenServer.call(pid, :get_count)
  end

  def handle_call(:get_count, _from, state) do
    {:reply, state.count, state}
  end
end
