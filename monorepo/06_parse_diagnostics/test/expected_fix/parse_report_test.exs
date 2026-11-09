defmodule ReachDemo.ParseDiagnostics.ExpectedFixTest do
  use ExUnit.Case, async: false
  @moduletag :expected_fix
  alias ReachDemo.Investigation06, as: I

  test "either proposed API includes a failure record for the specific invalid input" do
    probe = I.diagnostics_probe()
    assert probe["from_sources_with_report_2"]["reports_invalid_input"] or
             probe["return_diagnostics_true"]["reports_invalid_input"]
  end
end
