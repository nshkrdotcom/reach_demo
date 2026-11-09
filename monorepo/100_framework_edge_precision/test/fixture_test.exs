defmodule ReachDemo.FrameworkPrecision.FixtureTest do
  use ExUnit.Case, async: true
  alias ReachDemo.Investigation100, as: I
  alias ReachDemo.Support, as: S

  test "all distinct Phoenix, Ecto and Ash fixture files are parseable" do
    assert length(I.fixture_paths()) == 9
    Enum.each(I.fixture_paths(), fn path ->
      source = path |> S.fixture!() |> File.read!()
      assert {:ok, _} = Code.string_to_quoted(source, file: path)
    end)
  end
end
