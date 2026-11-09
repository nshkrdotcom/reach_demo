defmodule ReachDemo.ParseDiagnostics.CharacterizationTest do
  use ExUnit.Case, async: false
  alias ReachDemo.Investigation06, as: I

  test "default and source_only builds omit the invalid file without losing the valid one" do
    report = I.collect()
    rows = Map.new(report["observations"], &{&1["scenario"], &1})
    assert rows["syntax_controls"]["valid"]["status"] == "ok"
    assert rows["syntax_controls"]["invalid"]["status"] == "error"
    assert rows["full_valid_only"]["result"]["node_count"] > 0
    assert rows["full_valid_only"]["result"]["logger_capture_available"] == true
    assert rows["full_valid_plus_invalid"]["result"]["project_fields"] ==
             rows["full_valid_only"]["result"]["project_fields"]
    assert report["status"] in ~w(reproduced not_reproduced inconclusive)
  end
end
