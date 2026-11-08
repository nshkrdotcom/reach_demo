defmodule ReachDemo.Messages.FixtureTest do
  use ExUnit.Case, async: false
  alias ReachDemo.{Support, Messages.Investigation}

  test "all layouts and controls parse without compiling conflicting duplicate module variants" do
    assert length(Support.fixture_sources!(Investigation.fixture_paths())) == 9
    source = File.read!("fixtures/same_file.ex")
    assert source =~ "GenServer.call(ReachDemo.Messages.ServerA"
    assert source =~ "{:from_a, key}"
    assert source =~ "{:from_b, key}"
  end

  test "guardless and guarded cases differ by a guard only" do
    a = File.read!("fixtures/guardless.ex")
    b = File.read!("fixtures/guarded.ex")
    assert a =~ "body_local ="
    assert b =~ "body_local ="
    assert b =~ "when is_atom(key)"
  end
end
