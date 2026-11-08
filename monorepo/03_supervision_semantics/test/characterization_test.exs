defmodule ReachDemo.Supervision.CharacterizationTest do
  use ExUnit.Case, async: false
  alias ReachDemo.Supervision.Investigation

  test "a real Reach OTP analysis returns structural evidence for each case" do
    rows =
      Enum.map(Investigation.cases(), fn {key, file, target} ->
        Investigation.inspect_case(key, file, target)
      end)

    assert length(rows) == 11
    assert Enum.all?(rows, &(&1["node_count"] > 0))
    assert Enum.all?(rows, &is_list(&1["all_supervisors"]))
    assert Enum.all?(rows, &is_map(&1["candidate_probes"]))
  end

  test "direct-call controls expose exact call IDs and containing scopes" do
    for {key, file, target} <- Investigation.cases(),
        key in ~w(direct direct_literal direct_named) do
      case_data = Investigation.inspect_case(key, file, target)
      assert [_ | _] = case_data["inline_trace"]

      for call <- case_data["inline_trace"] do
        assert call["call_module"] == "Elixir.Supervisor"
        assert call["call_function"] == "start_link"
        assert is_list(call["containing_functions"])
        assert is_list(call["containing_modules"])
      end
    end
  end
end
