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

  test "Phoenix action and Ecto cast examples use normal framework shapes" do
    phoenix = "fixtures/phoenix/with_fallback.ex" |> S.fixture!() |> File.read!()
    ecto = "fixtures/ecto/paired.ex" |> S.fixture!() |> File.read!()
    assert phoenix =~ "def show(_conn, %{"
    assert phoenix =~ "action_fallback"
    assert ecto =~ "Ecto.Changeset.cast({%{}, %{name: :string}}"
  end
end
