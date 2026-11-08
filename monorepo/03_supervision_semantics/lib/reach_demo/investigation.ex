defmodule ReachDemo.Supervision.Investigation do
  @moduledoc "RD-03: identify actual Reach supervisor reports, separately from source-derived candidate hypotheses."
  alias ReachDemo.Support, as: S

  @workers "fixtures/workers.ex"
  @cases [
    {"standard", "fixtures/standard.ex", "Elixir.ReachDemo.Supervision.StandardSupervisor"},
    {"direct", "fixtures/direct.ex", "Elixir.ReachDemo.Supervision.DirectSupervisor"},
    {"direct_literal", "fixtures/direct_literal.ex",
     "Elixir.ReachDemo.Supervision.DirectLiteral"},
    {"direct_named", "fixtures/direct_named.ex", "Elixir.ReachDemo.Supervision.DirectNamed"},
    {"one_for_one", "fixtures/strategy_one_for_one.ex",
     "Elixir.ReachDemo.Supervision.StrategyOneForOne"},
    {"one_for_all", "fixtures/strategy_one_for_all.ex",
     "Elixir.ReachDemo.Supervision.StrategyOneForAll"},
    {"rest_for_one", "fixtures/strategy_rest_for_one.ex",
     "Elixir.ReachDemo.Supervision.StrategyRestForOne"},
    {"child_policies", "fixtures/child_policies.ex",
     "Elixir.ReachDemo.Supervision.ChildPolicies"},
    {"dynamic", "fixtures/dynamic.ex", "Elixir.ReachDemo.Supervision.Dynamic"},
    {"false_positive", "fixtures/false_positive.ex",
     "Elixir.ReachDemo.Supervision.NotASupervisor"},
    {"negative", "fixtures/negative.ex", "Elixir.ReachDemo.Supervision.PlainUtility"}
  ]

  def cases, do: @cases

  def collect do
    provenance = S.qualify!()
    _ = provenance
    observations = Enum.map(@cases, fn {key, file, target} -> inspect_case(key, file, target) end)
    standard = find_case(observations, "standard")
    direct = find_case(observations, "direct")
    std_children = target_children(standard)
    direct_children = target_children(direct)
    cli_standard = cli_probe("fixtures/standard.ex")
    cli_direct = cli_probe("fixtures/direct.ex")
    direct_controls = Enum.map(~w(direct direct_literal direct_named), &find_case(observations, &1))

    direct_calls_with_scopes? =
      Enum.all?(direct_controls, fn row ->
        Enum.any?(row["inline_trace"], fn call ->
          call["call_module"] == "Elixir.Supervisor" and
            call["call_function"] == "start_link" and
            call["containing_functions"] != [] and call["containing_modules"] != []
        end)
      end)

    # Without a discovered direct supervisor, the standard/direct comparison is inconclusive.
    status =
      cond do
        standard["target_supervisors"] == [] or direct["target_supervisors"] == [] ->
          "inconclusive"

        std_children == [] and direct_children != [] ->
          "reproduced"

        true ->
          "not_reproduced"
      end

    %{
      status: status,
      analysis_scopes: [
        %{
          "kind" => "per-fixture project IR",
          "api" => "Reach.Project.from_sources/2(source_only: true)"
        },
        %{
          "kind" => "full unfiltered OTP node analysis",
          "api" => "Reach.OTP.Analysis.run(project, nil)"
        }
      ],
      inputs: S.input_records([@workers | Enum.map(@cases, &elem(&1, 1))]),
      observations: observations,
      oracle_expectations: [
        %{
          "scenario" => "standard",
          "children" => ["WorkerA", "WorkerB"],
          "strategy" => "one_for_one",
          "basis" => "authored Supervisor.init/2 and OTP child-spec semantics"
        },
        %{
          "scenario" => "direct",
          "children" => ["WorkerA", "WorkerB"],
          "basis" => "Supervisor.start_link/2 literal configuration"
        },
        %{
          "scenario" => "direct_controls",
          "variants" => ["direct", "direct_literal", "direct_named"],
          "basis" =>
            "Each variant calls Supervisor.start_link/2; list literal versus variable and enclosing function name are controlled differences."
        },
        %{
          "scenario" => "false_positive",
          "is_supervisor" => false,
          "basis" => "only uses GenServer and calls unrelated Foo.init/1"
        },
        %{
          "scenario" => "strategy_variants",
          "one_for_one" => "failed child only",
          "one_for_all" => "all affected children",
          "rest_for_one" => "failed child and later-started children"
        },
        %{
          "scenario" => "child_policies",
          "restart" => ["permanent", "transient", "temporary"],
          "shutdown" => [3000, 5000, "brutal_kill"]
        }
      ],
      comparisons: [
        %{
          "kind" => "standard_vs_direct",
          "status" => status,
          "standard_child_extraction_status" =>
            cond do
              standard["target_supervisors"] == [] -> "inconclusive"
              std_children == [] -> "reproduced"
              true -> "not_reproduced"
            end,
          "standard_reported_children" => std_children,
          "direct_reported_children" => direct_children,
          "extraction_asymmetry_observed" => std_children == [] and direct_children != []
        },
        %{
          "kind" => "candidate_deduplication",
          "public_result_exposes_only_deduplicated_candidates" => true,
          "source_algorithm" =>
            "init candidates ++ inline candidates |> Enum.uniq_by(& &1.module)",
          "standard_source_candidate_probes" => standard["candidate_probes"]
        },
        %{
          "kind" => "false_positive",
          "status" =>
            if(find_case(observations, "false_positive")["target_supervisors"] != [] and
                 find_case(observations, "negative")["target_supervisors"] == [],
              do: "reproduced",
              else: "not_reproduced"
            ),
          "genserver_reported" =>
            find_case(observations, "false_positive")["target_supervisors"] != [],
          "negative_control_reported" =>
            find_case(observations, "negative")["target_supervisors"] != []
        },
        %{
          "kind" => "CLI_vs_library_supervision",
          "standard_cli" => cli_standard,
          "direct_cli" => cli_direct,
          "standard_library_supervisors" => standard["all_supervisors"],
          "direct_library_supervisors" => direct["all_supervisors"],
          "standard_equivalent_child_lists" => compare_cli_children(cli_standard, standard),
          "direct_equivalent_child_lists" => compare_cli_children(cli_direct, direct)
        },
        %{
          "kind" => "direct_call_discovery",
          "status" =>
            cond do
              not direct_calls_with_scopes? -> "inconclusive"
              Enum.all?(direct_controls, &(&1["target_supervisors"] == [])) -> "reproduced"
              true -> "not_reproduced"
            end,
          "variants" =>
            Enum.map(~w(direct direct_literal direct_named), fn key ->
              row = find_case(observations, key)

              %{
                "scenario" => key,
                "recognized" => row["target_supervisors"] != [],
                "call_count" => length(row["inline_trace"]),
                "calls_with_containing_functions" =>
                  Enum.count(row["inline_trace"], &(&1["containing_functions"] != [])),
                "calls_with_enclosing_modules" =>
                  Enum.count(row["inline_trace"], &(&1["containing_modules"] != []))
              }
            end)
        },
        %{
          "kind" => "strategy_metadata",
          "each_returned_record_keys" =>
            Enum.map(observations, fn row ->
              %{"scenario" => row["scenario"], "keys" => row["result_fields"]}
            end)
        }
      ],
      diagnostics: [
        %{
          "note" =>
            "Discovery candidate probes are source-derived, not a private Reach API result; initial supervisor candidates are not exposed before deduplication."
        },
        %{
          "note" =>
            "Top-level status describes only standard-vs-direct child extraction. Direct discovery, conventional child extraction and GenServer false-positive findings have separate statuses in comparisons."
        }
      ]
    }
    |> Map.put(:classification, "precision_limitation")
    |> S.result!("RD-03")
  end

  def inspect_case(key, file, target) do
    paths = if key == "negative", do: [file], else: [@workers, file]
    project = S.project!(paths, source_only: true)
    result = Reach.OTP.Analysis.run(project, nil)

    supervision =
      Enum.map(result.supervision || [], fn sup ->
        %{
          "module" => S.text(sup.module),
          "children" => Enum.map(sup.children || [], &S.text/1),
          "location" => S.rel_location(sup.location),
          "keys" => Map.keys(Map.from_struct(sup)) |> Enum.map(&S.text/1) |> Enum.sort()
        }
      end)

    %{
      "scenario" => key,
      "analysis_scope" => "source-only project IR, unfiltered OTP node analysis",
      "api" => "Reach.OTP.Analysis.run(project, nil)",
      "input" => S.rel(file),
      "node_count" => map_size(project.nodes),
      "module_functions" => function_summaries(project),
      "result_fields" =>
        if(supervision == [], do: [], else: supervision |> hd() |> Map.fetch!("keys")),
      "all_supervisors" => supervision,
      "target_supervisors" => Enum.filter(supervision, &(&1["module"] == target)),
      "candidate_probes" => candidate_probes(project, target),
      "inline_trace" =>
        if(key in ~w(direct direct_literal direct_named),
          do: inline_trace(project),
          else: []
        )
    }
  end

  defp function_summaries(project) do
    project.nodes
    |> Map.values()
    |> Enum.filter(&(&1.type == :function_def))
    |> Enum.map(fn n -> "#{S.text(n.meta[:module])}.#{n.meta[:name]}/#{n.meta[:arity]}" end)
    |> Enum.sort()
  end

  # Reconstruct the same containing-function/module search from the published
  # Reach source. These are source-derived traces, not private API return values.
  defp inline_trace(project) do
    nodes = Map.values(project.nodes)

    nodes
    |> Enum.filter(fn n ->
      n.type == :call and n.meta[:module] == Supervisor and
        n.meta[:function] == :start_link
    end)
    |> Enum.sort_by(& &1.id)
    |> Enum.map(fn call ->
      parents =
        nodes
        |> Enum.filter(fn node ->
          node.type == :function_def and
            Enum.any?(Reach.IR.all_nodes(node), &(&1.id == call.id))
        end)
        |> Enum.map(fn node ->
          %{
            "node_id" => node.id,
            "module" => S.text(node.meta[:module]),
            "name" => S.text(node.meta[:name]),
            "arity" => node.meta[:arity]
          }
        end)
        |> Enum.sort_by(& &1["node_id"])

      modules =
        nodes
        |> Enum.filter(fn node ->
          node.type == :module_def and
            Enum.any?(Reach.IR.all_nodes(node), &(&1.id == call.id))
        end)
        |> Enum.map(fn node ->
          %{"node_id" => node.id, "name" => S.text(node.meta[:name])}
        end)
        |> Enum.sort_by(& &1["node_id"])

      first_arg = List.first(call.children)
      span = S.node_record(call)

      %{
        "call_node_id" => call.id,
        "call_module" => S.text(call.meta[:module]),
        "call_function" => S.text(call.meta[:function]),
        "file" => span["file"],
        "line" => span["line"],
        "first_arg_type" => if(first_arg, do: S.text(first_arg.type), else: nil),
        "first_arg_meta" => if(first_arg, do: S.safe(first_arg.meta), else: nil),
        "containing_functions" => parents,
        "containing_modules" => modules
      }
    end)
  end

  # Source-observed signatures for explaining candidate creation; not claimed to be
  # actual pre-dedup Reach return values (find_supervision/1 is private).
  defp candidate_probes(project, target) do
    nodes = Map.values(project.nodes)

    init_defs =
      Enum.filter(nodes, fn n ->
        n.type == :function_def and n.meta[:name] == :init and n.meta[:arity] == 1 and
          S.text(n.meta[:module]) == target
      end)

    init_hits =
      Enum.flat_map(init_defs, fn def_node ->
        Reach.IR.all_nodes(def_node)
        |> Enum.filter(fn child ->
          child.type == :call and
            child.meta[:function] in [:init, :supervise, :child_spec, :start_link]
        end)
        |> Enum.map(fn n ->
          %{
            "function" => S.text(n.meta[:function]),
            "call_module" => S.text(n.meta[:module]),
            "node_id" => n.id
          }
        end)
      end)

    inline_calls =
      Enum.filter(nodes, fn n ->
        n.type == :call and n.meta[:module] == Supervisor and n.meta[:function] == :start_link
      end)

    %{
      "init_name_match_calls" => init_hits,
      "supervisor_start_link_calls" => Enum.map(inline_calls, & &1.id),
      "candidate_paths_may_overlap" => init_hits != [] and inline_calls != []
    }
  end

  # Reach's documented CLI is a separate executable entry point. The output is
  # a real child process's JSON envelope, not a re-render of the library result.
  def cli_probe(file) do
    mix = System.find_executable("mix") || raise("mix executable not found")
    args = ["reach.otp", file, "--format", "json"]
    {stdout, exit_status} = System.cmd(mix, args, stderr_to_stdout: true)

    decoded =
      try do
        {:ok, JSON.decode!(String.trim(stdout))}
      rescue
        error -> {:error, Exception.message(error)}
      end

    case decoded do
      {:ok, doc} ->
        %{
          "command" => "mix " <> Enum.join(args, " "),
          "exit_status" => exit_status,
          "json_valid" => true,
          "cli_supervision" => Map.get(doc, "supervision", []),
          "cli_command" => Map.get(doc, "command")
        }

      {:error, reason} ->
        %{
          "command" => "mix " <> Enum.join(args, " "),
          "exit_status" => exit_status,
          "json_valid" => false,
          "parse_error" => reason,
          "stdout" => String.slice(stdout, 0, 2000)
        }
    end
  end

  defp compare_cli_children(%{"cli_supervision" => sup, "exit_status" => 0}, library) do
    lib =
      library["all_supervisors"]
      |> Enum.map(fn row ->
        {row["module"], row["children"]}
      end)
      |> Enum.sort()

    cli =
      sup
      |> Enum.map(fn row ->
        {row["module"], row["children"]}
      end)
      |> Enum.sort()

    lib == cli
  end

  defp compare_cli_children(_cli, _library), do: nil

  defp find_case(rows, key), do: Enum.find(rows, &(&1["scenario"] == key))
  defp target_children(%{"target_supervisors" => [%{"children" => children} | _]}), do: children
  defp target_children(_), do: []

  def run!, do: S.run!("RD-03", &collect/0)
end
