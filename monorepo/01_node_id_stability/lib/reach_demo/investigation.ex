defmodule ReachDemo.NodeIDs.Investigation do
  @moduledoc "RD-01: reproducible semantic matching across source revisions and independent BEAM IR IDs."
  alias ReachDemo.Support, as: S
  alias ReachDemo.Support.Locators

  @fixtures ~w(fixtures/target_before.ex fixtures/target_after.ex fixtures/target_comment.ex fixtures/target_file.ex fixtures/a_earlier.ex fixtures/z_other.ex fixtures/beam_one.ex fixtures/beam_two.ex)
  def fixture_paths, do: @fixtures

  def source_entries(paths) do
    project = S.project!(paths, source_only: true)
    Locators.entries(project, :target)
  end

  def compare(a_paths, b_paths) do
    a = source_entries(a_paths)
    b = source_entries(b_paths)
    rows = Locators.compare(a, b)

    %{
      "a_paths" => Enum.map(a_paths, &S.rel/1),
      "b_paths" => Enum.map(b_paths, &S.rel/1),
      "rows" => rows,
      "summary" => summary(rows)
    }
  end

  defp summary(rows) do
    exact = Enum.filter(rows, &(&1["confidence"] == "exact" and &1["present_in_both"]))

    %{
      "exact_matches" => length(exact),
      "changed_ids" => Enum.count(exact, &(&1["id_equal"] == false)),
      "unchanged_ids" => Enum.count(exact, &(&1["id_equal"] == true)),
      "ambiguous_or_missing" => length(rows) - length(exact)
    }
  end

  def source_namespace do
    ["fixtures/target_file.ex", "fixtures/z_other.ex"]
    |> then(&S.project!(&1, source_only: true))
    |> then(fn project ->
      project.nodes |> Map.keys() |> Enum.sort()
    end)
  end

  def beam_namespace do
    prior = Code.get_compiler_option(:debug_info)
    Code.put_compiler_option(:debug_info, true)

    try do
      Enum.map(["fixtures/beam_one.ex", "fixtures/beam_two.ex"], fn path ->
        compiled = Code.compile_file(S.fixture!(path))
        if compiled == [], do: raise("Code.compile_file returned no modules for #{path}")

        results =
          Enum.map(compiled, fn {mod, bytes} ->
            case Reach.Frontend.BEAM.from_bytecode(bytes, file: path) do
              {:ok, ir_nodes} ->
                all = Reach.IR.all_nodes(ir_nodes)

                %{
                  "module" => S.text(mod),
                  "file" => S.rel(path),
                  "ir_node_count" => length(all),
                  "ids" => Enum.map(all, & &1.id) |> Enum.sort(),
                  "definitions" =>
                    Enum.filter(all, &(&1.type == :function_def))
                    |> Enum.map(fn n ->
                      %{"name" => S.text(n.meta[:name]), "arity" => n.meta[:arity], "id" => n.id}
                    end)
                }

              {:error, reason} ->
                %{
                  "module" => S.text(mod),
                  "file" => S.rel(path),
                  "error" => inspect(reason),
                  "ids" => []
                }
            end
          end)

        %{"input" => S.rel(path), "compiled_modules" => results}
      end)
    after
      Code.put_compiler_option(:debug_info, prior)
    end
  end

  def collect do
    _ = S.qualify!()
    unchanged_a = compare(["fixtures/target_before.ex"], ["fixtures/target_before.ex"])
    unchanged_b = compare(["fixtures/target_before.ex"], ["fixtures/target_after.ex"])
    comment = compare(["fixtures/target_before.ex"], ["fixtures/target_comment.ex"])

    early =
      compare(
        ["fixtures/target_file.ex", "fixtures/z_other.ex"],
        ["fixtures/a_earlier.ex", "fixtures/target_file.ex", "fixtures/z_other.ex"]
      )

    reversed =
      compare(
        ["fixtures/target_file.ex", "fixtures/z_other.ex"],
        ["fixtures/z_other.ex", "fixtures/target_file.ex"]
      )

    beams = beam_namespace()
    ids = beams |> Enum.flat_map(& &1["compiled_modules"]) |> Enum.map(&Map.get(&1, "ids", []))

    overlap =
      case ids do
        [first, second | _] ->
          MapSet.intersection(MapSet.new(first), MapSet.new(second))
          |> MapSet.to_list()
          |> Enum.sort()

        _ ->
          []
      end

    source_ids = source_namespace()

    cross_ids =
      MapSet.intersection(MapSet.new(source_ids), MapSet.new(Enum.concat(ids)))
      |> MapSet.to_list()
      |> Enum.sort()

    count_missing =
      Enum.any?([unchanged_a, unchanged_b, comment, early, reversed], fn x ->
        x["summary"]["exact_matches"] == 0
      end)

    beam_errors =
      Enum.any?(beams, fn x -> Enum.any?(x["compiled_modules"], &Map.has_key?(&1, "error")) end)

    status = if count_missing or beam_errors, do: "inconclusive", else: "reproduced"

    %{
      status: status,
      inputs: S.input_records(@fixtures),
      analysis_scopes: [
        %{"scope" => "one source file", "api" => "Reach.Project.from_sources(source_only: true)"},
        %{
          "scope" => "source file index / order",
          "api" => "Reach.Project.from_sources(paths, ...)"
        },
        %{"scope" => "separate BEAM graphs", "api" => "Reach.Frontend.BEAM.from_bytecode/2"}
      ],
      observations: [
        %{"scenario" => "identical_inputs", "comparison" => unchanged_a},
        %{"scenario" => "earlier_definition", "comparison" => unchanged_b},
        %{"scenario" => "comment_only", "comparison" => comment},
        %{"scenario" => "earlier_sorting_file", "comparison" => early},
        %{"scenario" => "file_order_permutation", "comparison" => reversed},
        %{
          "scenario" => "BEAM_per_module",
          "results" => beams,
          "raw_numeric_id_overlap" => overlap
        },
        %{
          "scenario" => "source_BEAM_numeric_overlap",
          "source_ids" => source_ids,
          "overlapping_ids" => cross_ids,
          "supported_cross_frontend_merge_tested" => false
        }
      ],
      oracle_expectations: [
        %{
          "rule" =>
            "Semantic correspondence uses module/function/arity, clause head, structural path and expression fingerprint; never raw ID or line"
        },
        %{"rule" => "Unrelated source edits do not change the meaning of target(value)"},
        %{"rule" => "No stable cross-revision identity guarantee was found in Reach's docs"}
      ],
      comparisons: [
        %{
          "question" => "file-index ID range sensitivity",
          "earlier_sort_change" => early["summary"],
          "explicit_order_change" => reversed["summary"]
        },
        %{
          "question" => "same-file AST sensitivity",
          "prior_definition_change" => unchanged_b["summary"],
          "comment_change" => comment["summary"]
        },
        %{
          "question" => "separate BEAM counters",
          "numeric_overlap_count" => length(overlap),
          "actual_graph_merge_performed" => false
        }
      ],
      diagnostics: [
        %{
          "source_reference" =>
            "lib/reach/project.ex @node_id_file_stride = 4294967296; parse_files/2 indexes supplied file order; lib/reach/frontend/beam.ex Counter.new()"
        },
        %{
          "note" =>
            "Numeric overlap is recorded as a scoped fact, never as proof of an unsafe supported merge."
        }
      ]
    }
    |> Map.put(:classification, "internal_identity_scope")
    |> S.result!("RD-01")
  end

  def run!, do: S.run!("RD-01", &collect/0)
end
