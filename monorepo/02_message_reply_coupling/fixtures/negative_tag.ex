defmodule ReachDemo.Messages.TagMismatch do
  def deliver(pid, data), do: send(pid, {:unexpected, data})
  def handle_info({:other, payload}, state), do: {:noreply, {payload, state}}
end
