defmodule ReachDemo.Messages.ExpectedFixTest do
  use ExUnit.Case, async: false
  @moduletag :expected_fix
  alias ReachDemo.Messages.Investigation

  test "GenServer.call to ServerA does not get ServerB reply flow" do
    c = Investigation.analyze(["fixtures/same_file.ex"])

    spurious =
      Enum.filter(c["reply_edges"], fn edge ->
        String.ends_with?(get_in(edge, ["source", "owner", "module"]) || "", "ServerB") and
          String.ends_with?(get_in(edge, ["target", "owner", "module"]) || "", "Caller")
      end)

    assert spurious == []
  end

  test "wrong arity handle_call/1 is not treated as a GenServer reply callback" do
    c = Investigation.analyze(["fixtures/wrong_arity.ex"])

    assert Enum.all?(c["reply_edges"], fn edge ->
             not String.ends_with?(
               get_in(edge, ["source", "owner", "module"]) || "",
               "NotACallback"
             )
           end)
  end
end
