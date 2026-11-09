defmodule ReachDemo.GenStatem.FixtureTest do
  use ExUnit.Case, async: true
  alias ReachDemo.Support, as: S
  alias ReachDemo.Investigation101, as: I

  test "all seven statem source fixtures have valid syntax" do
    assert length(I.fixture_paths()) == 7
    paths = I.fixture_paths()
    Enum.each(paths, fn path ->
      source = path |> S.fixture!() |> File.read!()
      assert {:ok, _} = Code.string_to_quoted(source, file: path)
    end)
  end

  test "dynamic mode deliberately contains no callback-mode literal" do
    source = "fixtures/dynamic_mode.ex" |> S.fixture!() |> File.read!()
    {:ok, ast} = Code.string_to_quoted(source)
    inspected = Macro.to_string(ast)
    refute String.contains?(inspected, ":state_functions")
    refute String.contains?(inspected, ":handle_event_function")
  end
end
