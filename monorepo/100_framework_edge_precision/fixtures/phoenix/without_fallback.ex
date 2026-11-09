defmodule ReachDemo.Frameworks.Phoenix.Control do
  use Phoenix.Controller
  def show(:bad), do: {:error, :invalid_request}
  def show(value), do: {:ok, value}
end
