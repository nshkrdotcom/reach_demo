defmodule ReachDemo.Investigation05 do
  @moduledoc "RD-05: resolved plugins lost between project selection and module SDG builds."
  alias ReachDemo.Support, as: S
  alias ReachDemo.PluginSDGs.ProbePlugin

  @fixture "fixtures/source.ex"
  @inferred "fixtures/inferred_project/lib/sample.ex"
  @dependency_only "fixtures/dependency_only_project/lib/sample.ex"
  @inputs [
    @fixture,
    "fixtures/inferred_project/mix.exs",
    @inferred,
    "fixtures/dependency_only_project/mix.exs",
    @dependency_only
  ]

  def fixture_paths, do: @inputs

  defp selected(plugins), do: Enum.map(plugins, &inspect/1) |> Enum.sort()

  defp edges(graph, nodes, label) do
    graph
    |> Graph.edges()
    |> Enum.filter(&(&1.label == label))
    |> Enum.sort_by(&{&1.v1, &1.v2})
    |> Enum.map(fn edge ->
      from = Map.get(nodes, edge.v1)
      to = Map.get(nodes, edge.v2)

      %{
        "label" => inspect(edge.label),
        "source_id" => edge.v1,
        "target_id" => edge.v2,
        "source_name" => if(from, do: S.text(from.meta[:name]), else: nil),
        "target_name" => if(to, do: S.text(to.meta[:name]), else: nil),
        "both_endpoints_in_index" => not is_nil(from) and not is_nil(to)
      }
    end)
  end

  defp standalone do
    path = S.fixture!(@fixture)
    {:ok, roots} = Reach.IR.from_string(File.read!(path), file: path)
    sdg = Reach.SystemDependence.build(roots, plugins: [ProbePlugin])
    edges(sdg.graph, sdg.nodes, ProbePlugin.local_label())
  end

  defp project(opts) do
    p = Reach.Project.from_sources([S.fixture!(@fixture)], opts)

    module_edges =
      p.modules
      |> Enum.map(fn {mod, sdg} ->
        local =
          if is_map(sdg) and Map.has_key?(sdg, :graph) and Map.has_key?(sdg, :nodes) do
            edges(sdg.graph, sdg.nodes, ProbePlugin.local_label())
          else
            []
          end

        {inspect(mod), local}
      end)
      |> Map.new()

    %{
      "selected_plugins" => selected(p.plugins),
      "node_count" => map_size(p.nodes),
      "module_count" => map_size(p.modules),
      "local_edges" => edges(p.graph, p.nodes, ProbePlugin.local_label()),
      "project_hook_edges" => edges(p.graph, p.nodes, ProbePlugin.project_label()),
      "retained_module_local_edges" => module_edges
    }
  end

  defp host_detection do
    detected = Reach.Plugin.detect()

    %{
      "ex_unit_available_in_host" => Code.ensure_loaded?(ExUnit.Case),
      "ex_unit_plugin_auto_detected" => Reach.Plugins.ExUnit in detected,
      "plugins_resolved_without_options" => selected(Reach.Plugin.resolve([])),
      "ex_unit_analyze_emits_edges" => false,
      "note" => "ExUnit tests host selection only; Reach.Plugins.ExUnit.analyze/2 emits no edges, so this does not demonstrate an unwanted SDG edge."
    }
  end

  defp ecto_cast_param_edges(path) do
    source = File.read!(path)
    {:ok, roots} = Reach.IR.from_string(source, file: path)
    nodes = Reach.IR.all_nodes(roots)
    ids = nodes |> Enum.map(& &1.id) |> MapSet.new()

    Reach.Plugins.Ecto.analyze(nodes, [])
    |> Enum.filter(fn {_from, _to, label} -> label == :ecto_cast_params end)
    |> Enum.map(fn {from, to, label} ->
      %{
        "source_id" => from,
        "target_id" => to,
        "label" => inspect(label),
        "both_endpoints_in_index" => MapSet.member?(ids, from) and MapSet.member?(ids, to)
      }
    end)
  end

  defp target_inference do
    # Positive control tests the Ecto local hook DIRECTLY. The full project
    # (no plugins: option) tests whether inferred Ecto reaches module SDGs.
    # Source contains an Ecto marker AND mix.exs declares :ecto; the next
    # separate probe tests dependency-only selection without source markers.
    path = S.fixture!(@inferred)
    p = Reach.Project.from_sources([path])
    source_only = Reach.Project.from_sources([path], source_only: true)
    direct = ecto_cast_param_edges(path)
    merged = edges(p.graph, p.nodes, :ecto_cast_params)

    %{
      "target_mix_file" => "fixtures/inferred_project/mix.exs",
      "direct_ecto_hook_edges" => direct,
      "full_project_ecto_cast_param_edges" => merged,
      "full_project_plugins" => selected(p.plugins),
      "source_only_plugins" => selected(source_only.plugins),
      "ecto_selected" => Reach.Plugins.Ecto in p.plugins,
      "ecto_loaded_in_host" => Code.ensure_loaded?(Ecto),
      "direct_control_valid" => direct != [] and Enum.all?(direct, & &1["both_endpoints_in_index"]),
      "note" => "A missing merged edge is evidence only if the direct Ecto hook emits a valid edge and full project selection includes Ecto."
    }
  end

  defp dependency_only_inference do
    path = S.fixture!(@dependency_only)
    source = File.read!(path)
    project = Reach.Project.from_sources([path], source_only: true)

    %{
      "target_mix_file" => "fixtures/dependency_only_project/mix.exs",
      "source_contains_ecto_name" => String.contains?(source, "Ecto"),
      "ecto_selected_from_path" => Reach.Plugins.Ecto in Reach.Plugin.resolve(paths: [path]),
      "ecto_loaded_in_host" => Code.ensure_loaded?(Ecto),
      "ecto_selected_by_source_project" => Reach.Plugins.Ecto in project.plugins,
      "selected_plugins" => selected(project.plugins),
      "note" => "Tests mix.exs inference separately; no Ecto call occurs in this source, so no Ecto-local edge is expected."
    }
  end

  defp safe_diagnostic(fun, defaults) do
    try do
      Map.put(fun.(), "probe_outcome", "returned")
    rescue
      error ->
        Map.merge(defaults, %{"probe_outcome" => "raised", "probe_error" => Exception.message(error)})
    catch
      kind, reason ->
        Map.merge(defaults, %{"probe_outcome" => "caught", "probe_error" => "#{kind}: #{inspect(reason)}"})
    end
  end

  def collect do
    direct = standalone()
    explicit = project(plugins: [ProbePlugin], retain_module_sdgs: true)
    no_retention = project(plugins: [ProbePlugin], retain_module_sdgs: false)
    disabled = project(plugins: [], retain_module_sdgs: true)
    inferred =
      safe_diagnostic(&target_inference/0, %{
        "direct_control_valid" => false,
        "ecto_selected" => false,
        "full_project_ecto_cast_param_edges" => []
      })

    dependency_only =
      safe_diagnostic(&dependency_only_inference/0, %{
        "ecto_selected_by_source_project" => false
      })

    controls_ok =
      length(direct) == 1 and
        Enum.all?(direct, & &1["both_endpoints_in_index"]) and
        length(explicit["project_hook_edges"]) == 1 and
        length(no_retention["project_hook_edges"]) == 1 and
        inspect(ProbePlugin) in explicit["selected_plugins"] and
        disabled["local_edges"] == [] and disabled["project_hook_edges"] == []

    retained_local_count = length(explicit["local_edges"])
    discarded_local_count = length(no_retention["local_edges"])

    status =
      cond do
        not controls_ok -> "inconclusive"
        retained_local_count == 0 and discarded_local_count == 0 -> "reproduced"
        retained_local_count == 1 and discarded_local_count == 1 -> "not_reproduced"
        true -> "inconclusive"
      end

    S.result!(
      %{
        status: status,
        classification: "resolved_plugins_not_forwarded_to_module_sdgs",
        inputs: S.input_records(@inputs),
        analysis_scopes: [
          %{api: "Reach.SystemDependence.build/2", scope: "direct positive local hook"},
          %{api: "Reach.Project.from_sources/2", scope: "explicit plugins with and without module retention"},
          %{api: "Reach.Project.from_sources/2", scope: "explicit plugins: [] control"},
          %{api: "Reach.Plugins.Ecto.analyze/2", scope: "direct Ecto positive control"},
          %{api: "Reach.Project.from_sources/2", scope: "inferred Ecto full-SDG versus source_only"},
          %{api: "Reach.Plugin.resolve/1", scope: "dependency-only mix.exs inference"}
        ],
        observations: [
          %{"scenario" => "direct_local_positive", "local_edges" => direct},
          %{"scenario" => "explicit_retain_true", "result" => explicit},
          %{"scenario" => "explicit_retain_false", "result" => no_retention},
          %{"scenario" => "disabled_project", "result" => disabled},
          %{"scenario" => "host_loaded_plugin_control",
            "result" => safe_diagnostic(&host_detection/0, %{})},
          %{"scenario" => "target_inference_full_graph", "result" => inferred},
          %{"scenario" => "dependency_only_inference", "result" => dependency_only}
        ],
        comparisons: [
          %{
            "name" => "local_vs_project_hooks",
            "controls_valid" => controls_ok,
            "explicit_retain_true_local" => retained_local_count,
            "explicit_retain_false_local" => discarded_local_count,
            "explicit_retain_true_project" => length(explicit["project_hook_edges"]),
            "explicit_retain_false_project" => length(no_retention["project_hook_edges"])
          },
          %{
            "name" => "ecto_inference_local_edges",
            "direct_control_valid" => inferred["direct_control_valid"],
            "full_project_ecto_selected" => inferred["ecto_selected"],
            "full_project_ecto_cast_param_edge_count" => length(inferred["full_project_ecto_cast_param_edges"]),
            "dependency_only_selected" => dependency_only["ecto_selected_by_source_project"]
          }
        ],
        oracle_expectations: [
          %{rule: "The same resolved plugin list should reach both module-local analyze/2 and project analyze_project/3 hooks."},
          %{rule: "An explicit plugins: [] should not be replaced by host auto-detection inside the module SDG builder."},
          %{rule: "Inferred Ecto can supply local cast-param edges when independently demonstrated by the Ecto hook."}
        ],
        diagnostics: [
          %{source_reference: "Reach.Project.from_sources resolves plugins; build_module_sdgs/2 omits plugins: when calling SystemDependence.build/2."},
          %{note: "RD-05 status uses the uniquely labeled ProbePlugin hooks. Ecto and host-selection results are independent supporting probes."}
        ]
      },
      "RD-05"
    )
  end

  def run!, do: S.run!("RD-05", &collect/0)
end
