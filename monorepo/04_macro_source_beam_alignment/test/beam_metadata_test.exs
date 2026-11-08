defmodule ReachDemo.MacroAlign.BeamMetadataTest do
  use ExUnit.Case, async: false
  alias ReachDemo.MacroAlign.Investigation

  test "no-debug payload is distinguished from native chunk presence" do
    result =
      Investigation.compile_with_tracer(
        ["fixtures/macros/generator.ex", "fixtures/macros/no_debug.ex"],
        "evidence/compiled/test_no_debug",
        false
      )

    assert Enum.all?(
             result["modules"],
             &(&1["abstract_chunk_status"] == "no_abstract_code" and
                 &1["raw_abstract_functions"] == [])
           )
  end
end
