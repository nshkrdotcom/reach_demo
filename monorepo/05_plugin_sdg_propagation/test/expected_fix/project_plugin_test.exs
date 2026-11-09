defmodule ReachDemo.PluginSDGs.ExpectedFixTest do
  use ExUnit.Case, async: false
  @moduletag :expected_fix
  alias ReachDemo.Investigation05, as: I

  test "module-local analyze/2 edge survives both project retention modes" do
    rows = Map.new(I.collect()["observations"], &{&1["scenario"], &1["result"]})
    assert length(rows["explicit_retain_true"]["local_edges"]) == 1
    assert length(rows["explicit_retain_false"]["local_edges"]) == 1
    assert length(rows["explicit_retain_true"]["project_hook_edges"]) == 1
    assert length(rows["explicit_retain_false"]["project_hook_edges"]) == 1
  end
end
