defmodule ReachDemo.NodeIDs.FixtureTest do
  use ExUnit.Case, async: false
  alias ReachDemo.{NodeIDs.Investigation, Support}

  test "variants are parseable and share the same unchanged target body" do
    assert length(Support.fixture_sources!(Investigation.fixture_paths())) == 8

    for f <- ~w(fixtures/target_before.ex fixtures/target_after.ex fixtures/target_comment.ex) do
      assert File.read!(f) =~ "def target(value), do: value + 1"
    end
  end
end
