defmodule ReachDemo.Supervision.ExpectedFixTest do
  use ExUnit.Case, async: false
  @moduletag :expected_fix
  alias ReachDemo.Supervision.Investigation

  test "conventional Supervisor.init children are represented" do
    case_data =
      Investigation.inspect_case(
        "standard",
        "fixtures/standard.ex",
        "Elixir.ReachDemo.Supervision.StandardSupervisor"
      )

    assert [%{"children" => children}] = case_data["target_supervisors"]
    assert length(children) == 2
  end

  test "plain GenServer calling Foo.init is not classified as supervisor" do
    case_data =
      Investigation.inspect_case(
        "false_positive",
        "fixtures/false_positive.ex",
        "Elixir.ReachDemo.Supervision.NotASupervisor"
      )

    assert case_data["target_supervisors"] == []
  end
end
