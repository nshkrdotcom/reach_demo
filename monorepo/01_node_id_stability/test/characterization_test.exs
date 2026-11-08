defmodule ReachDemo.NodeIDs.CharacterizationTest do
  use ExUnit.Case, async: false
  alias ReachDemo.NodeIDs.Investigation

  test "semantic source locators match identical inputs unambiguously" do
    comparison =
      Investigation.compare(["fixtures/target_before.ex"], ["fixtures/target_before.ex"])

    assert comparison["summary"]["exact_matches"] > 0
    assert comparison["summary"]["changed_ids"] == 0
  end

  test "record structural matches instead of equating raw IDs across variants" do
    comparison =
      Investigation.compare(["fixtures/target_before.ex"], ["fixtures/target_after.ex"])

    assert is_list(comparison["rows"])
    assert Enum.all?(comparison["rows"], &Map.has_key?(&1, "semantic_locator"))
  end
end
