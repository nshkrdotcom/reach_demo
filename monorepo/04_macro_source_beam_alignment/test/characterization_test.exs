defmodule ReachDemo.MacroAlign.CharacterizationTest do
  use ExUnit.Case, async: false
  alias ReachDemo.MacroAlign.Investigation

  test "Reach collects actual source IR and macro facts before compilation" do
    data =
      Investigation.source_layers([
        "fixtures/macros/genserver.ex",
        "fixtures/macros/two_invocations.ex"
      ])

    assert data["project_node_count"] > 0
    assert is_list(data["macro_fact_files"])
    assert Enum.all?(data["macro_fact_files"], &is_list(&1["facts"]))
  end

  test "a real compiler tracer implementing trace/2 exists" do
    assert Code.ensure_loaded?(ReachDemo.MacroAlign.CompilerTracer)
    assert function_exported?(ReachDemo.MacroAlign.CompilerTracer, :trace, 2)
  end
end
