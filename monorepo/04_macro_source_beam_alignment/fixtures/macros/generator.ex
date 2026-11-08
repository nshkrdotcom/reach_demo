defmodule ReachDemo.MacroAlign.Generator do
  defmacro def_generated(name, value) do
    quote do
      def unquote(name)(), do: unquote(value)
    end
  end
end
