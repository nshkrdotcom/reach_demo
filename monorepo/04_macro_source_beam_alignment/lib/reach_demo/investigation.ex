defmodule ReachDemo.MacroAlign.Investigation do
  @moduledoc "RD-04: provenance layers and separately recorded compiler-derived raw annotations."
  alias ReachDemo.Support, as: S
  alias ReachDemo.MacroAlign.CompilerTracer

  @main_sources ~w(fixtures/macros/generator.ex fixtures/macros/genserver.ex fixtures/macros/single_macro.ex fixtures/macros/two_invocations.ex fixtures/macros/authored.ex)
  @no_debug "fixtures/macros/no_debug.ex"
  def fixture_paths, do: @main_sources ++ [@no_debug]

  def source_layers(files) do
    project = S.project!(files, source_only: true)

    facts =
      Enum.map(files, fn file ->
        case Reach.MacroFact.collect_file(file) do
          {:ok, all_facts} ->
            %{"file" => S.rel(file), "facts" => Enum.map(all_facts, &fact_record/1)}

          {:error, reason} ->
            raise "Macro fact collection failed for #{file}: #{inspect(reason)}"
        end
      end)

    funcs =
      project.nodes
      |> Map.values()
      |> Enum.filter(&(&1.type == :function_def))
      |> Enum.map(fn node ->
        %{
          "module" => S.text(node.meta[:module]),
          "function" => S.text(node.meta[:name]),
          "arity" => node.meta[:arity],
          "source_line" => get_in(Map.from_struct(node), [:source_span, :start_line]),
          "origin" => S.safe(node.meta[:origin]),
          "file" => S.rel(get_in(Map.from_struct(node), [:source_span, :file]))
        }
      end)
      |> Enum.sort_by(&{&1["module"], &1["function"], &1["arity"]})

    %{
      "api" => "Reach.Project.from_sources/2 source_only; Reach.MacroFact.collect_file/2",
      "source_ir_function_definitions" => funcs,
      "macro_fact_files" => facts,
      "project_node_count" => map_size(project.nodes)
    }
  end

  defp fact_record(fact) do
    %{
      "kind" => S.text(fact.kind),
      "framework" => S.text(fact.framework),
      "owner_module" => S.text(fact.owner_module),
      "name" => S.text(fact.name),
      "arity" => fact.arity,
      "generated_flag" => fact.generated?,
      "confidence" => S.text(fact.confidence),
      "call_module" => S.text(fact.call_module),
      "source" => S.safe(fact.source),
      "explained_callbacks" => S.safe(Map.get(fact.data || %{}, :explained_callbacks, nil))
    }
  end

  def compile_with_tracer(files, output_dir, debug_info) do
    files = S.fixture_sources!(files)
    old_debug = Code.get_compiler_option(:debug_info)
    old_tracers = Code.get_compiler_option(:tracers)
    File.rm_rf!(output_dir)
    File.mkdir_p!(output_dir)
    :persistent_term.put({CompilerTracer, :sink}, self())
    Code.put_compiler_option(:debug_info, debug_info)
    Code.put_compiler_option(:tracers, Enum.uniq([CompilerTracer | List.wrap(old_tracers)]))

    try do
      result =
        Kernel.ParallelCompiler.compile_to_path(files, output_dir, return_diagnostics: true)

      traces = drain_traces([])

      case result do
        {:ok, modules, diagnostics} ->
          %{
            "source_files_compiled" => Enum.map(files, &S.rel/1),
            "modules" =>
              Enum.map(modules, fn mod ->
                path = Path.join(output_dir, Atom.to_string(mod) <> ".beam")
                if !File.regular?(path), do: raise("Missing compiled BEAM: #{path}")
                inspect_beam(mod, File.read!(path))
              end),
            "compiler_trace_events" => traces,
            "compiler_diagnostics" => Enum.map(diagnostics, &bounded/1),
            "debug_info_requested" => debug_info
          }

        {:error, errors, warnings} ->
          raise "Fixture compilation failed: #{inspect({errors, warnings}, limit: 8)}"

        other ->
          raise "Unexpected ParallelCompiler result: #{inspect(other, limit: 5)}"
      end
    after
      Code.put_compiler_option(:debug_info, old_debug)
      Code.put_compiler_option(:tracers, old_tracers)
      :persistent_term.erase({CompilerTracer, :sink})
    end
  end

  defp drain_traces(acc) do
    receive do
      {:reach_demo_compiler_trace, record} ->
        if length(acc) >= 400, do: Enum.reverse(acc), else: drain_traces([record | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  def inspect_beam(mod, bytecode) do
    source_nodes =
      case Reach.Frontend.BEAM.from_bytecode(bytecode, file: Atom.to_string(mod) <> ".beam") do
        {:ok, nodes} ->
          Reach.IR.all_nodes(nodes)
          |> Enum.filter(&(&1.type == :function_def))
          |> Enum.map(fn n ->
            %{
              "function" => S.text(n.meta[:name]),
              "arity" => n.meta[:arity],
              "reach_ir_id" => n.id,
              "span" => S.safe(n.source_span),
              "origin" => S.safe(n.meta[:origin])
            }
          end)

        {:error, reason} ->
          %{"error" => inspect(reason)}
      end

    chunks = %{
      "exports" => chunk(bytecode, :exports),
      "abstract_code" => chunk(bytecode, :abstract_code),
      "debug_info" => chunk(bytecode, :debug_info)
    }

    abstract = raw_abstract(chunks["abstract_code"])
    {:ok, ^mod, native_chunks} = :beam_lib.all_chunks(bytecode)
    chunk_ids = Enum.map(native_chunks, fn {id, _} -> to_string(id) end)
    debug_present = "Dbgi" in chunk_ids

    %{
      "module" => S.text(mod),
      "bytecode_sha256" => :crypto.hash(:sha256, bytecode) |> Base.encode16(case: :lower),
      "native_chunk_ids" => chunk_ids,
      "debug_info_payload" => bounded(chunks["debug_info"]),
      "abstract_code_payload_status" => bounded(chunks["abstract_code"] |> abstract_payload()),
      "debug_info_chunk_present" => debug_present,
      "debug_info_chunk_status" => chunk_status(chunks["debug_info"]),
      "abstract_chunk_status" => chunk_status(chunks["abstract_code"]),
      "exports" => exports(chunks["exports"]),
      "raw_abstract_functions" => abstract,
      "reach_beam_definitions" => source_nodes
    }
  end

  # The raw :function Erlang tuples are inspected directly, before *any*
  # Reach Frontend.BEAM transformation. Attribute :file events are carried to
  # associate a best-available source file with subsequent function forms.
  defp raw_abstract({:ok, {:raw_abstract_v1, forms}}) do
    {_file, collected} =
      Enum.reduce(forms, {nil, []}, fn
        {:attribute, _anno, :file, {file, _line}}, {_old, acc} ->
          {S.rel(to_string(file)), acc}

        {:function, anno, name, arity, _clauses}, {file, acc} ->
          rec = %{
            "function" => S.text(name),
            "arity" => arity,
            "raw_annotation" => bounded(anno),
            "annotation_line" => anno_call(:line, anno),
            "annotation_file" => anno_call(:file, anno),
            "file_attribute" => file,
            "generated_annotation" => anno_call(:generated, anno)
          }

          {file, [rec | acc]}

        _other, state ->
          state
      end)

    Enum.reverse(collected)
  end

  defp raw_abstract(_), do: []

  defp anno_call(function, annotation) do
    try do
      if function_exported?(:erl_anno, function, 1) do
        result = apply(:erl_anno, function, [annotation])

        if is_binary(result) or is_number(result) or is_boolean(result) or is_nil(result),
          do: result,
          else: S.safe(result)
      else
        "api_unavailable"
      end
    rescue
      _ -> "annotation_unavailable"
    catch
      _, _ -> "annotation_unavailable"
    end
  end

  defp chunk(bytecode, which) do
    case :beam_lib.chunks(bytecode, [which]) do
      {:ok, {_mod, [{^which, data}]}} -> {:ok, data}
      {:error, _} = error -> error
      other -> {:error, {:unexpected_chunk, which, bounded(other)}}
    end
  end

  defp abstract_payload({:ok, {:raw_abstract_v1, forms}}), do: {:raw_abstract_v1, length(forms)}
  defp abstract_payload(other), do: other

  defp chunk_status({:ok, :no_abstract_code}), do: "no_abstract_code"
  defp chunk_status({:ok, :no_debug_info}), do: "no_debug_info"
  defp chunk_status({:ok, _}), do: "present"
  defp chunk_status({:error, reason}), do: "unavailable: " <> bounded(reason)

  defp exports({:ok, list}), do: Enum.map(list, fn {name, arity} -> "#{name}/#{arity}" end)
  defp exports(_), do: []

  defp bounded(term), do: inspect(term, limit: 10, printable_limit: 400)

  def invocation_sites(file, invocation_names) do
    File.read!(S.fixture!(file))
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _i} ->
      Enum.any?(invocation_names, &String.contains?(line, "def_generated(:#{&1}"))
    end)
    |> Enum.map(fn {line, i} ->
      %{"line" => i, "expression" => String.trim(line), "file" => S.rel(file)}
    end)
  end

  def build_correspondences(compiled) do
    target = Enum.find(compiled["modules"], &String.ends_with?(&1["module"], "TwoInvocations"))
    sites = invocation_sites("fixtures/macros/two_invocations.ex", ~w(alpha beta))

    Enum.map(~w(alpha beta), fn fun ->
      candidates =
        if target,
          do: Enum.filter(target["raw_abstract_functions"], &(&1["function"] == fun)),
          else: []

      site = Enum.find(sites, &String.contains?(&1["expression"], ":#{fun}"))

      traces =
        Enum.filter(compiled["compiler_trace_events"], fn rec ->
          rec["kind"] in ["local_macro", "remote_macro"] and site != nil and
            rec["line"] == site["line"] and rec["file"] == site["file"] and
            rec["enclosing_module"] == target["module"]
        end)

      lines = Enum.map(candidates, & &1["annotation_line"])

      quality =
        cond do
          candidates == [] -> "unavailable"
          site == nil -> "unmatched"
          length(candidates) > 1 -> "ambiguous"
          length(traces) > 0 and site["line"] in lines -> "possible"
          true -> "ambiguous"
        end

      %{
        "generated_function" => fun <> "/0",
        "authored_invocation" => site,
        "raw_abstract_form_matches" => candidates,
        "trace_events_at_invocation" => traces,
        "qualified_correspondence" => quality,
        "causal_exact_match_demonstrated" => false
      }
    end)
  end

  def collect do
    _ = S.qualify!()
    _ = S.fixture_sources!(fixture_paths())
    sources = source_layers(@main_sources)
    work = Path.join("evidence", "compiled")
    compiled = compile_with_tracer(@main_sources, Path.join(work, "debug"), true)
    # Generator is already loaded from first controlled compilation. The second
    # compilation is separate and requests genuinely absent debug info.
    without_debug = compile_with_tracer([@no_debug], Path.join(work, "no_debug"), false)
    correspondences = build_correspondences(compiled)

    missing =
      Enum.any?(
        compiled["modules"],
        &(&1["reach_beam_definitions"] == %{"error" => ":no_debug_info"})
      )

    %{
      status: if(missing, do: "inconclusive", else: "reproduced"),
      inputs: S.input_records(fixture_paths()),
      analysis_scopes: [
        %{
          "scope" => "unexpanded authored source",
          "api" => "Reach.Project.from_sources(source_only: true)"
        },
        %{"scope" => "macro source fact layer", "api" => "Reach.MacroFact.collect_file/2"},
        %{"scope" => "compiled binary", "api" => "Reach.Frontend.BEAM.from_bytecode/2"},
        %{
          "scope" => "raw BEAM abstract form + metadata",
          "api" => ":beam_lib.chunks/2, :erl_anno.line/file/generated"
        },
        %{
          "scope" => "traced controlled fixture compilation",
          "api" =>
            "Code.put_compiler_option(:tracers,...); Kernel.ParallelCompiler.compile_to_path/3"
        }
      ],
      observations: [
        %{"layer" => "reach_source_and_macro_facts", "data" => sources},
        %{"layer" => "compiled_with_debug", "data" => compiled},
        %{"layer" => "compiled_without_debug", "data" => without_debug},
        %{
          "layer" => "authored_invocation_sites",
          "sites" => invocation_sites("fixtures/macros/two_invocations.ex", ~w(alpha beta))
        },
        %{"layer" => "invocation_to_BEAM_candidate_correspondence", "rows" => correspondences}
      ],
      oracle_expectations: [
        %{
          "expectation" =>
            "two distinct remote macro invocations produce alpha/0 and beta/0, respectively",
          "authority" => "custom macro and controlled compiler"
        },
        %{
          "expectation" =>
            "an explicitly authored control is distinguishable from generated definitions when provenance permits"
        },
        %{
          "expectation" =>
            "unavailable debug metadata is established by compiler setting and observed BEAM chunks, not by missing source"
        }
      ],
      comparisons: [
        %{
          "name" => "two_invocations",
          "correspondence_rows" => correspondences,
          "exact_links_observed" =>
            Enum.count(correspondences, &(&1["qualified_correspondence"] == "exact"))
        },
        %{
          "name" => "macro_fact_vs_BEAM",
          "source_macro_fact_count" =>
            Enum.reduce(sources["macro_fact_files"], 0, fn row, n -> n + length(row["facts"]) end),
          "BEAM_debug_modules" => length(compiled["modules"]),
          "tracer_event_count" => length(compiled["compiler_trace_events"])
        },
        %{
          "name" => "no_debug",
          "requested_debug_info" => false,
          "metadata" =>
            without_debug["modules"]
            |> Enum.map(
              &Map.take(&1, [
                "module",
                "native_chunk_ids",
                "debug_info_payload",
                "abstract_code_payload_status",
                "debug_info_chunk_present",
                "abstract_chunk_status",
                "reach_beam_definitions"
              ])
            )
        }
      ],
      diagnostics: [
        %{
          "source_reference" =>
            "lib/reach/macro_fact.ex; lib/reach/source/origin.ex; lib/reach/frontend/beam.ex"
        },
        %{
          "caution" =>
            "Line coincidence and compiler macro invocation events alone do not establish exact causal source-to-generated-definition links."
        },
        %{
          "caution" =>
            "Compiler-tracer events are filtered to real events supplied by Elixir; no synthetic generated_function event is assumed."
        }
      ]
    }
    |> Map.put(:classification, "feature_gap")
    |> S.result!("RD-04")
  end

  def run!, do: S.run!("RD-04", &collect/0)
end
