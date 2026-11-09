defmodule ReachDemo.Investigation06 do
  @moduledoc "RD-06: requested files silently omitted from ordinary project results."
  alias ReachDemo.Support, as: S

  @valid "fixtures/valid.ex"
  @invalid "fixtures/invalid.ex"
  @unknown "fixtures/non_elixir.txt"
  @inputs [@valid, @invalid, @unknown]
  @reach_284_fields ~w(cache_key call_graph graph modules nodes plugins summaries)

  def fixture_paths, do: @inputs

  defp syntax(path) do
    source = File.read!(S.fixture!(path))

    case Code.string_to_quoted(source, file: path) do
      {:ok, _} -> %{"status" => "ok"}
      {:error, reason} -> %{"status" => "error", "reason" => inspect(reason)}
    end
  end

  defp parse_failure_in_report?(term) do
    # This is a forward-compatible probe of optional APIs. It does NOT treat
    # the absence of a guessed field name as proof of the observed 2.8.4 bug.
    flat = inspect(term, limit: :infinity, printable_limit: 20000)
    String.contains?(flat, "invalid.ex") and
      Regex.match?(~r/(?:\berror\b|\bfailed\b|parse_error|syntax_error|reason:|status: :skipped)/i, flat)
  end

  defp summarize_project(project, requested_paths) do
    fields = project |> Map.from_struct() |> Map.keys() |> Enum.map(&to_string/1) |> Enum.sort()
    defs = project.nodes |> Map.values() |> Enum.filter(&(&1.type == :function_def))

    %{
      "requested_inputs" => requested_paths,
      "returned_type" => inspect(project.__struct__),
      "node_count" => map_size(project.nodes),
      "function_count" => length(defs),
      "function_names" => defs |> Enum.map(&S.text(&1.meta[:name])) |> Enum.sort(),
      "project_fields" => fields,
      "matches_2_8_4_project_field_set" => fields == @reach_284_fields,
      "has_new_project_fields" => fields -- @reach_284_fields != [],
      "reports_specific_parse_failure" => parse_failure_in_report?(project)
    }
  end

  defp build(paths, opts) do
    project = Reach.Project.from_sources(Enum.map(paths, &S.fixture!/1), opts)
    summarize_project(project, paths)
  end

  defp capture_build(paths, opts) do
    # mix test starts ExUnit already; mix run does not. Start it explicitly so
    # CaptureLog/CaptureIO work in both modes (ExUnit.CaptureServer exists).
    {:ok, _started} = Application.ensure_all_started(:ex_unit)

    {{summary, stderr}, logger} =
      ExUnit.CaptureLog.with_log(fn ->
        ExUnit.CaptureIO.with_io(:stderr, fn -> build(paths, opts) end)
      end)

    Map.merge(summary, %{
      "logger_capture_available" => true,
      "logger_output" => String.slice(logger, 0, 4000),
      "stderr_output" => String.slice(stderr, 0, 4000)
    })
  end

  defp safe_side_probe(fun) do
    try do
      %{"outcome" => "returned", "result" => fun.()}
    rescue
      error ->
        %{"outcome" => "raised", "exception" => Exception.message(error)}
    catch
      kind, reason ->
        %{"outcome" => "caught", "kind" => S.text(kind), "reason" => inspect(reason)}
    end
  end

  def diagnostics_probe do
    paths = Enum.map([@valid, @invalid], &S.fixture!/1)

    alternate =
      if function_exported?(Reach.Project, :from_sources_with_report, 2) do
        # apply/3 avoids a compile warning on pinned Reach 2.8.4, where the
        # proposed API does not exist.
        result = apply(Reach.Project, :from_sources_with_report, [paths, [plugins: []]])
        %{
          "available" => true,
          "reports_invalid_input" => parse_failure_in_report?(result),
          "result_excerpt" => String.slice(inspect(result, limit: 80), 0, 2400)
        }
      else
        %{"available" => false, "reports_invalid_input" => false}
      end

    flagged = Reach.Project.from_sources(paths, plugins: [], return_diagnostics: true)

    %{
      "from_sources_with_report_2" => alternate,
      "return_diagnostics_true" => %{
        "reports_invalid_input" => parse_failure_in_report?(flagged),
        "returned_type" =>
          if(is_map(flagged), do: inspect(Map.get(flagged, :__struct__)), else: inspect(flagged))
      }
    }
  end

  def collect do
    valid_syntax = syntax(@valid)
    invalid_syntax = syntax(@invalid)
    unknown_syntax = syntax(@unknown)

    full_good = capture_build([@valid], plugins: [])
    full_mixed = capture_build([@valid, @invalid], plugins: [])
    source_good = capture_build([@valid], plugins: [], source_only: true)
    source_mixed = capture_build([@valid, @invalid], plugins: [], source_only: true)
    diag_api = diagnostics_probe()

    # Secondary, isolated probe of Reach.Frontend.language_from_path's :elixir
    # fallback for an explicit file with a non-source extension. Not part of
    # the headline classification: if it raises, the main evidence survives.
    fallback = safe_side_probe(fn -> capture_build([@valid, @unknown], plugins: []) end)

    controls_valid = valid_syntax["status"] == "ok" and invalid_syntax["status"] == "error"

    equal_full = full_good["node_count"] > 0 and
      full_good["node_count"] == full_mixed["node_count"] and
      full_good["function_names"] == full_mixed["function_names"]

    equal_source = source_good["node_count"] > 0 and
      source_good["node_count"] == source_mixed["node_count"]

    has_diagnostics =
      diag_api["from_sources_with_report_2"]["reports_invalid_input"] or
        diag_api["return_diagnostics_true"]["reports_invalid_input"] or
        full_mixed["reports_specific_parse_failure"]

    status =
      cond do
        not controls_valid or not equal_full or not equal_source -> "inconclusive"
        has_diagnostics -> "not_reproduced"
        true -> "reproduced"
      end

    S.result!(
      %{
        status: status,
        classification: "parse_failure_omitted_from_project_result",
        inputs: S.input_records(@inputs),
        analysis_scopes: [
          %{api: "Reach.Project.from_sources/2", scope: "default full SDG (primary)"},
          %{api: "Reach.Project.from_sources/2", scope: "source_only comparison"},
          %{api: "Reach.Frontend.language_from_path/1", scope: "unknown-extension fallback (separate side probe)"}
        ],
        observations: [
          %{"scenario" => "syntax_controls", "valid" => valid_syntax, "invalid" => invalid_syntax,
            "unknown_extension" => unknown_syntax},
          %{"scenario" => "full_valid_only", "result" => full_good},
          %{"scenario" => "full_valid_plus_invalid", "result" => full_mixed},
          %{"scenario" => "source_only_valid_only", "result" => source_good},
          %{"scenario" => "source_only_valid_plus_invalid", "result" => source_mixed},
          %{"scenario" => "unknown_extension_fallback", "result" => fallback},
          %{"scenario" => "diagnostic_api_probe", "result" => diag_api}
        ],
        comparisons: [
          %{
            "name" => "invalid_input_omitted_from_default_project",
            "controls_valid" => controls_valid,
            "same_default_graph_nodes" => equal_full,
            "same_source_only_nodes" => equal_source,
            "machine_readable_report_observed" => has_diagnostics
          }
        ],
        oracle_expectations: [
          %{rule: "A project-building API should account for every requested path with a parse status and reason."},
          %{rule: "Full SDG and source_only modes must identify requested but omitted files."}
        ],
        diagnostics: [
          %{source_reference: "Reach.Project.parse_path/3 maps {:error, reason} to nil; parse_files/2 filters it."},
          %{note: "Task timeouts and unavailable Gleam/glance dependencies may raise/exit; they are NOT silent-drop evidence."},
          %{note: "Logger/stderr capture is supplementary; the issue concerns the returned project API."}
        ]
      },
      "RD-06"
    )
  end

  def run!, do: S.run!("RD-06", &collect/0)
end
