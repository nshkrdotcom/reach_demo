defmodule ReachDemo.MacroAlign.ExpectedFixTest do
  use ExUnit.Case, async: false
  @moduletag :expected_fix
  alias ReachDemo.MacroAlign.Investigation

  test "exact source invocation to generated function link is independently demonstrable" do
    report = Investigation.collect()

    observation =
      Enum.find(
        report["observations"],
        &(&1["layer"] == "invocation_to_BEAM_candidate_correspondence")
      )

    assert Enum.all?(observation["rows"], &(&1["qualified_correspondence"] == "exact"))
  end
end
