defmodule ReachDemo.Frameworks.Phoenix.SampleController do
  # Controller-shaped declaration and a normal two-argument action.
  # Reach parses this source without compiling Phoenix macros.
  use Phoenix.Controller
  action_fallback ReachDemo.Frameworks.Phoenix.Fallback

  def show(_conn, %{"status" => "bad"}), do: {:error, :invalid_request}
  def show(conn, _params), do: conn
end

defmodule ReachDemo.Frameworks.Phoenix.UnrelatedUtility do
  # Not an action in the controller declaring the fallback.
  def calculate(:bad), do: {:error, :not_a_web_action}
  def calculate(value), do: {:ok, value}
end
