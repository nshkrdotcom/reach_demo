defmodule ReachDemo.Frameworks.Phoenix.Router do
  # Realistic Phoenix-shaped declaration: action_fallback is module-level DSL.
  # Source analysis parses this without compiling Phoenix macros.
  use Phoenix.Controller
  action_fallback ReachDemo.Frameworks.Phoenix.Fallback

  def show(:bad), do: {:error, :invalid_request}
  def show(value), do: {:ok, value}
end

defmodule ReachDemo.Frameworks.Phoenix.UnrelatedUtility do
  def calculate(:bad), do: {:error, :not_a_web_action}
  def calculate(value), do: {:ok, value}
end
