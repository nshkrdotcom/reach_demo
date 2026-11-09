defmodule ReachDemo.PluginSDGs.CharacterizationTest do
  use ExUnit.Case, async: false
  alias ReachDemo.Investigation05, as: I

  test "both probe hooks work and the retained/unretained builds are characterized" do
    report = I.collect()
    rows = Map.new(report["observations"], &{&1["scenario"], &1})
    assert length(rows["direct_local_positive"]["local_edges"]) == 1
    assert length(rows["explicit_retain_true"]["result"]["project_hook_edges"]) == 1
    assert length(rows["explicit_retain_false"]["result"]["project_hook_edges"]) == 1
    assert rows["disabled_project"]["result"]["project_hook_edges"] == []
    assert report["status"] in ~w(reproduced not_reproduced inconclusive)
  end
end
