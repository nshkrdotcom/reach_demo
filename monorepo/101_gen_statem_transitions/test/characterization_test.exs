defmodule ReachDemo.GenStatem.CharacterizationTest do
  use ExUnit.Case, async: false
  alias ReachDemo.Investigation101, as: I

  test "two standard callback modes are recognized and their transitions recorded" do
    report = I.collect()
    rows = Map.new(report["observations"], &{&1["scenario"], &1["result"]})
    basic = rows["fixtures/state_functions_basic.ex"]
    event = rows["fixtures/handle_event_basic.ex"]
    assert basic["recognized"] and event["recognized"]
    assert basic["callback_mode"] == "state_functions"
    assert event["callback_mode"] == "handle_event_function"
    assert is_list(basic["transitions"]) and is_list(event["transitions"])
    assert report["status"] == "inconclusive"
  end
end
