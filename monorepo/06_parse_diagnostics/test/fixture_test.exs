defmodule ReachDemo.ParseDiagnostics.FixtureTest do
  use ExUnit.Case, async: false
  alias ReachDemo.Investigation06, as: I
  alias ReachDemo.Support, as: S

  test "input set includes a valid fixture, invalid syntax, and non-Elixir extension fallback file" do
    assert length(I.fixture_paths()) == 3
    assert {:ok, _} = "fixtures/valid.ex" |> S.fixture!() |> File.read!() |> Code.string_to_quoted()
    assert {:error, _} = "fixtures/invalid.ex" |> S.fixture!() |> File.read!() |> Code.string_to_quoted()
    assert "fixtures/non_elixir.txt" |> S.fixture!() |> File.regular?()
    assert {:error, _} = "fixtures/non_elixir.txt" |> S.fixture!() |> File.read!() |> Code.string_to_quoted()
  end
end
