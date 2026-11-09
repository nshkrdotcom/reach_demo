defmodule ReachDemo.PluginSDGs.FixtureTest do
  use ExUnit.Case, async: true
  alias ReachDemo.Investigation05, as: I
  alias ReachDemo.Support, as: S

  test "analysis fixture and inert target Mix/project source parse" do
    assert length(I.fixture_paths()) == 5
    for path <- I.fixture_paths() do
      {:ok, _} = path |> S.fixture!() |> File.read!() |> Code.string_to_quoted()
    end
  end
end
