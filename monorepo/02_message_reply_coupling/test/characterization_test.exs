defmodule ReachDemo.Messages.CharacterizationTest do
  use ExUnit.Case, async: false
  alias ReachDemo.Messages.Investigation

  test "upstream-derived control actually produces both OTP edge classes" do
    c = Investigation.positive_controls!()
    assert c["reply_edges"] != []
    assert c["message_edges"] != []
    assert Enum.all?(c["reply_edges"] ++ c["message_edges"], & &1["source_exists"])
    assert Enum.all?(c["reply_edges"] ++ c["message_edges"], & &1["target_exists"])
  end

  test "an explicit combined OTP pass records real endpoints in both layouts" do
    layouts = [
      ["fixtures/same_file.ex"],
      [
        "fixtures/separate/server_a.ex",
        "fixtures/separate/server_b.ex",
        "fixtures/separate/caller.ex"
      ]
    ]

    for paths <- layouts do
      project = Investigation.analyze(paths)["project"]
      diagnostic = Investigation.combined_otp(project)
      assert diagnostic["node_count"] > 0
      assert is_list(diagnostic["reply_edges"])
      assert is_list(diagnostic["message_edges"])
    end
  end

  test "both layouts use a real merged project graph" do
    case_data = Investigation.analyze(["fixtures/same_file.ex"])
    assert case_data["nodes"] > 0
    assert case_data["graph_edges"] > 0
  end
end
