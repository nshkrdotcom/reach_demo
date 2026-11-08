defmodule ReachDemo.MacroAlign.CompilerTracer do
  @moduledoc "Real Elixir trace/2 callback; delivers bounded macro-related observations to the driver."
  # Compiler tracer contract: event, Macro.Env; the fixture compilation is run
  # *after* this module has been installed via Code.put_compiler_option(:tracers,...).
  @max_inspection 250

  def trace(event, env) do
    case normalize(event, env) do
      nil ->
        :ok

      record ->
        case :persistent_term.get({__MODULE__, :sink}, nil) do
          pid when is_pid(pid) -> send(pid, {:reach_demo_compiler_trace, record})
          _ -> :ok
        end

        :ok
    end
  end

  defp normalize({:remote_macro, meta, module, name, arity}, env) do
    %{
      "kind" => "remote_macro",
      "callee_module" => text(module),
      "callee" => text(name),
      "arity" => arity,
      "line" => Keyword.get(meta, :line),
      "file" => relative(env.file),
      "enclosing_module" => text(env.module)
    }
  end

  defp normalize({:local_macro, meta, name, arity}, env) do
    %{
      "kind" => "local_macro",
      "callee" => text(name),
      "arity" => arity,
      "line" => Keyword.get(meta, :line),
      "file" => relative(env.file),
      "enclosing_module" => text(env.module)
    }
  end

  defp normalize({:on_module, _bytecode, _}, env) do
    %{
      "kind" => "on_module",
      "line" => env.line,
      "file" => relative(env.file),
      "enclosing_module" => text(env.module),
      "note" => "Module completion is not an invocation-to-definition causal map"
    }
  end

  defp normalize(_other, _env), do: nil
  defp text(nil), do: nil
  defp text(v) when is_atom(v), do: Atom.to_string(v)
  defp text(v), do: inspect(v, printable_limit: @max_inspection)
  defp relative(nil), do: nil
  defp relative(file), do: ReachDemo.Support.rel(to_string(file))
end
