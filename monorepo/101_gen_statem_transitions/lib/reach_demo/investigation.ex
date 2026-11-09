defmodule ReachDemo.Investigation101 do
  @moduledoc "INV-101: source-only gen_statem transition and callback coverage."
  alias ReachDemo.Support, as: S

  @fixtures ~w(
    fixtures/state_functions_basic.ex
    fixtures/handle_event_basic.ex
    fixtures/state_enter_mode.ex
    fixtures/keep_repeat.ex
    fixtures/postpone_timeout.ex
    fixtures/guarded_clauses.ex
    fixtures/dynamic_mode.ex
    fixtures/attr_mode.ex
  )

  def fixture_paths, do: @fixtures

  defp render_transition(t) do
    n = Map.get(t, :node)
    %{
      "from" => S.safe(Map.get(t, :from)),
      "to" => S.safe(Map.get(t, :to)),
      "trigger" => S.safe(Map.get(t, :trigger)),
      "node_id" => if(is_map(n), do: Map.get(n, :id), else: nil)
    }
  end

  def analyze_file(path) do
    full = S.fixture!(path)
    source = File.read!(full)
    {:ok, _ast} = Code.string_to_quoted(source, file: full)
    {:ok, roots} = Reach.IR.from_string(source, file: full)
    ir_count = roots |> Reach.IR.all_nodes() |> length()

    case Reach.OTP.GenStatem.analyze(roots) do
      nil ->
        %{"recognized" => false, "ir_node_count" => ir_count,
          "reason" => "Reach.OTP.GenStatem returned nil"}

      result ->
        events =
          result.states
          |> Enum.map(fn {state, meta} ->
            event_types =
              meta
              |> Map.get(:events, [])
              |> Enum.map(&S.safe(Map.get(&1, :event_type)))
            {inspect(state), event_types}
          end)
          |> Map.new()

        transitions = Enum.map(result.transitions, &render_transition/1)
        %{
          "recognized" => true,
          "ir_node_count" => ir_count,
          "callback_mode" => S.safe(result.callback_mode),
          "init_state" => S.safe(result.init_state),
          "states_and_event_types" => events,
          "transitions" => transitions,
          "trigger_summary" => %{
            "total_transitions" => length(transitions),
            "nil_triggers" => Enum.count(transitions, &is_nil(&1["trigger"])),
            "self_loop_transitions" => Enum.count(transitions, &(&1["from"] == &1["to"]))
          }
        }
    end
  end

  defp cli_probe(path) do
    args = ["reach.otp", path, "--format", "json"]

    case System.find_executable("mix") do
      nil ->
        %{"command" => "mix " <> Enum.join(args, " "), "available" => false,
          "reason" => "mix executable unavailable"}

      executable ->
        {output, exit_status} = System.cmd(executable, args, stderr_to_stdout: true)

        decoded =
          case JSON.decode(String.trim(output)) do
            {:ok, data} ->
              %{"json_valid" => true,
            "top_level_keys" => if(is_map(data), do: Map.keys(data) |> Enum.sort(), else: []),
            "decoded" => S.safe(data)}

            {:error, why} ->
              %{"json_valid" => false, "decode_error" => inspect(why)}
          end

        Map.merge(decoded, %{
          "command" => "mix " <> Enum.join(args, " "),
          "available" => true,
          "exit_status" => exit_status,
          "output_excerpt" => String.slice(output, 0, 5000)
        })
    end
  end

  defp safe_probe(fun) do
    try do
      Map.put(fun.(), "probe_outcome", "returned")
    rescue
      error ->
        %{"probe_outcome" => "raised", "error" => Exception.message(error)}
    catch
      kind, reason ->
        %{"probe_outcome" => "caught", "error" => "#{kind}: #{inspect(reason)}"}
    end
  end

  defp preflattened_module_probe do
    path = "fixtures/state_functions_basic.ex"
    full = S.fixture!(path)
    {:ok, roots} = Reach.IR.from_string(File.read!(full), file: full)
    modules = Enum.filter(Reach.IR.all_nodes(roots), &(&1.type == :module_def))

    case modules do
      [mod] ->
        direct = Reach.OTP.GenStatem.analyze(roots)
        repeated = Reach.OTP.GenStatem.analyze([mod | Reach.IR.all_nodes(mod)])

        %{
          "direct_transitions" => length(direct.transitions),
          "preflattened_transitions" => length(repeated.transitions),
          "preflattened_roots_count" => length([mod | Reach.IR.all_nodes(mod)]),
          "note" => "This models the nested IR input assembled by Reach.OTP.Analysis.find_gen_statems; GenStatem.analyze/1 descends again."
        }
      _ -> raise("Expected exactly one module in state_functions_basic.ex")
    end
  end

  defp finding_comparisons(observations, cli_observations, probe) do
    library = Map.new(observations, &{&1["scenario"], &1["result"]})
    cli = Map.new(cli_observations, &{&1["scenario"], &1["result"]})
    basic = library["fixtures/state_functions_basic.ex"] || %{}
    attr = library["fixtures/attr_mode.ex"] || %{}
    dynamic = library["fixtures/dynamic_mode.ex"] || %{}
    cli_basic = cli["cli:fixtures/state_functions_basic.ex"] || %{}

    cli_transitions =
      (get_in(cli_basic, ["decoded", "state_machines"]) || [])
      |> Enum.flat_map(&Map.get(&1, "transitions", []))
      |> length()

    library_count = length(Map.get(basic, "transitions", []))
    reflattened_count = probe["preflattened_transitions"]

    [
      %{
        "finding" => "duplicate_gen_statem_reporting",
        "observed" => library_count == 2 and reflattened_count == 8 and
          cli_basic["exit_status"] == 0 and cli_basic["json_valid"] == true and
          cli_transitions == 8,
        "library_transition_count" => library_count,
        "preflattened_transition_count" => reflattened_count,
        "cli_transition_count" => cli_transitions,
        "cli_json_valid" => cli_basic["json_valid"] == true
      },
      %{
        "finding" => "module_attribute_callback_mode",
        "observed" => attr["recognized"] == true and
          attr["callback_mode"] == "state_functions" and
          Map.get(attr, "transitions", []) == [],
        "source_callback_mode" => "handle_event_function (via @mode)",
        "reported_callback_mode" => attr["callback_mode"],
        "reported_transition_count" => length(Map.get(attr, "transitions", [])),
        "dynamic_fallback_reported_mode" => dynamic["callback_mode"],
        "note" => "An attribute literal should be distinguishable from truly dynamic callback mode; neither result should be claimed as a runtime execution."
      }
    ]
    |> Enum.map(fn finding ->
      Map.put(finding, "status", if(finding["observed"], do: "reproduced", else: "inconclusive"))
    end)
  end

  def collect do
    observations = Enum.map(@fixtures, fn path ->
      %{"scenario" => path, "result" => safe_probe(fn -> analyze_file(path) end)}
    end)

    cli_observations = Enum.map(@fixtures, fn path ->
      %{"scenario" => "cli:" <> path, "result" => safe_probe(fn -> cli_probe(path) end)}
    end)

    reflattened_probe = safe_probe(&preflattened_module_probe/0)

    S.result!(
      %{
        status: "inconclusive",
        classification: "investigation_only_gen_statem_coverage",
        inputs: S.input_records(@fixtures),
        comparisons: finding_comparisons(observations, cli_observations, reflattened_probe),
        analysis_scopes: [
          %{api: "Reach.OTP.GenStatem.analyze/1", scope: "eight inert source fixtures"},
          %{api: "mix reach.otp <fixture> --format json", scope: "all eight independent source fixtures"}
        ],
        observations: observations ++ cli_observations ++
          [%{"scenario" => "library_preflattened_ir", "result" => reflattened_probe}],
        oracle_expectations: [
          %{rule: "Basic literal next_state transitions are positive controls."},
          %{rule: "Dynamic callback_mode with no recognizable literal must be marked unresolved, or explicitly heuristic."},
          %{rule: "A statically literal module attribute in callback_mode/0 should not be silently treated as state_functions."},
          %{rule: "State-functions-mode transition triggers may be nil due to implementation; this is a coverage difference, not automatically a bug."},
          %{rule: "keep_state/repeat_state currently need separate qualification; missing self-loops may be deliberate."},
          %{rule: "State-enter events, timeouts, postponed events and guards do not automatically imply feasible runtime transitions."}
        ],
        diagnostics: [
          %{note: "Every fixture is passed to the user-facing mix reach.otp CLI. CLI exit codes and JSON validity are observations, not automatic bug classifications."},
          %{note: "The dynamic-mode fixture contains neither callback-mode atom; Reach's default mode must be checked without accidentally triggering literal detection."}
        ]
      },
      "INV-101"
    )
  end

  def run!, do: S.run!("INV-101", &collect/0)
end
