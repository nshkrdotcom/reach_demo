defmodule Demo.CtrlA do
  use Phoenix.Controller
  action_fallback Demo.FallbackA
  def show(conn, params) do
    case lookup(params) do
      {:ok, v} -> json(conn, v)
      {:error, _} = err -> err
    end
  end
  defp lookup(_), do: {:error, :nope}
end

defmodule Demo.CtrlB do
  use Phoenix.Controller
  action_fallback Demo.FallbackB
  def index(_conn, _), do: {:error, :other}
end
