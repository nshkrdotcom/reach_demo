defmodule ReachDemo.FrameworkPrecision.CharacterizationTest do
  use ExUnit.Case, async: false
  alias ReachDemo.Investigation100, as: I

  test "local and project plugin hooks provide usable positive controls" do
    report = I.collect()
    rows = Map.new(report["observations"], &{&1["scenario"], &1["results"]})
    local = rows["direct_local_hooks"]
    project = rows["project_hooks"]

    assert map_size(local) == 5
    assert Enum.all?(local, fn {_name, result} -> result["probe_outcome"] == "returned" end)
    assert local["phoenix_fallback"]["local_hook_edges"] != []
    assert local["phoenix_control"]["local_hook_edges"] == []
    assert local["ecto_paired"]["local_hook_edges"] != []
    assert local["ecto_control"]["local_hook_edges"] == []

    assert project["ash_same_name_project"]["probe_outcome"] == "returned"
    assert project["ash_different_name_project"]["probe_outcome"] == "returned"
    assert report["status"] == "inconclusive"
  end
end
