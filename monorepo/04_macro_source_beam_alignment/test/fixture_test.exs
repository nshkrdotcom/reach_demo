defmodule ReachDemo.MacroAlign.FixtureTest do
  use ExUnit.Case, async: false
  alias ReachDemo.{Support, MacroAlign.Investigation}

  test "all six macro and authored source files parse" do
    assert length(Support.fixture_sources!(Investigation.fixture_paths())) == 6
  end

  test "two macro invocations have different authored source lines" do
    sites = Investigation.invocation_sites("fixtures/macros/two_invocations.ex", ~w(alpha beta))
    assert length(sites) == 2
    assert Enum.at(sites, 0)["line"] != Enum.at(sites, 1)["line"]
  end
end
