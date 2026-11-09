defmodule ReachDemo.FrameworkPrecision.CharacterizationTest do
  use ExUnit.Case, async: false
  alias ReachDemo.Investigation100, as: I

  test "read-only local and project plugin hooks return structured facts" do
    report = I.collect()
    rows = Map.new(report["observations"], &{&1["scenario"], &1["results"]})
    assert map_size(rows["direct_local_hooks"]) == 5
    assert Map.has_key?(rows["project_hooks"], "ash_same_name_project")
    assert Map.has_key?(rows["project_hooks"], "ash_different_name_project")
    assert report["status"] == "inconclusive"
  end
end
