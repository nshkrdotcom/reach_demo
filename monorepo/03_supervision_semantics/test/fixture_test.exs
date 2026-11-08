defmodule ReachDemo.Supervision.FixtureTest do
  use ExUnit.Case, async: false
  alias ReachDemo.{Support, Supervision.Investigation}

  test "every supervision fixture parses and independent case labels are distinct" do
    files = ["fixtures/workers.ex" | Enum.map(Investigation.cases(), &elem(&1, 1))]
    assert length(files) == length(Enum.uniq(files))
    assert length(Support.fixture_sources!(files)) == 12
  end

  test "the idiomatic fixture has both a start_link and init callback" do
    source = File.read!("fixtures/standard.ex")
    assert source =~ "def start_link(arg)"
    assert source =~ "def init(_arg)"
    assert source =~ "Supervisor.init(children, strategy: :one_for_one)"
  end

  test "unrelated init control is a GenServer, not a Supervisor" do
    source = File.read!("fixtures/false_positive.ex")
    assert source =~ "use GenServer"
    assert source =~ "Foo.init(value)"
    refute source =~ "use Supervisor"
  end
end
