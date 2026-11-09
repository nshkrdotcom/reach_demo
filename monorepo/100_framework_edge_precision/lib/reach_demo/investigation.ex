defmodule ReachDemo.Investigation100 do
  @moduledoc "INV-100: Phoenix, Ecto, Ash rule-precision probes (not confirmed bugs)."
  alias ReachDemo.Support, as: S

  @local_cases [
    {"phoenix_fallback", "fixtures/phoenix/with_fallback.ex", Reach.Plugins.Phoenix},
    {"phoenix_control", "fixtures/phoenix/without_fallback.ex", Reach.Plugins.Phoenix},
    {"ecto_paired", "fixtures/ecto/paired.ex", Reach.Plugins.Ecto},
    {"ecto_control", "fixtures/ecto/no_cast.ex", Reach.Plugins.Ecto},
    {"ecto_repo_suffix", "fixtures/ecto/repo_suffix_control.ex", Reach.Plugins.Ecto}
  ]
  @ash_base ["fixtures/ash/domain_a.ex", "fixtures/ash/resource_a.ex"]
  @ash_same @ash_base ++ ["fixtures/ash/resource_b.ex"]
  @ash_different @ash_base ++ ["fixtures/ash/resource_different.ex"]

  def fixture_paths do
    (@local_cases |> Enum.map(&elem(&1, 1))) ++ @ash_same ++ @ash_different
    |> Enum.uniq()
  end

  defp owner_index(nodes) do
    nodes
    |> Enum.filter(&(&1.type == :function_def))
    |> Enum.reduce(%{}, fn function, owners ->
      owner = "#{S.text(function.meta[:module])}.#{S.text(function.meta[:name])}/#{function.meta[:arity]}"
      Enum.reduce(Reach.IR.all_nodes(function), owners, fn node, acc ->
        Map.put_new(acc, node.id, owner)
      end)
    end)
  end

  defp node_record(id, index, owners) do
    case Map.get(index, id) do
      nil -> %{"id" => id, "missing" => true}
      node ->
        span = node.source_span || %{}
        %{
          "id" => id,
          "type" => S.text(node.type),
          "module" => S.safe(node.meta[:module]),
          "function" => S.safe(node.meta[:function]),
          "value" => S.safe(node.meta[:value]),
          "line" => span[:start_line],
          "file" => S.rel(span[:file]),
          "owner" => Map.get(owners, id)
        }
    end
  end

  defp edge_records(raw_edges, index, owners) do
    Enum.map(raw_edges, fn {a, b, label} ->
      %{
        "label" => inspect(label),
        "source" => node_record(a, index, owners),
        "target" => node_record(b, index, owners)
      }
    end)
    |> Enum.sort_by(&{&1["label"], &1["source"]["id"], &1["target"]["id"]})
  end

  def analyze_file(path, plugin) do
    full = S.fixture!(path)
    source = File.read!(full)
    {:ok, _} = Code.string_to_quoted(source, file: full)
    {:ok, roots} = Reach.IR.from_string(source, file: full)
    nodes = Reach.IR.all_nodes(roots)
    index = Map.new(nodes, &{&1.id, &1})
    owners = owner_index(nodes)

    %{
      "api" => "#{inspect(plugin)}.analyze/2",
      "node_count" => length(nodes),
      "call_sites" =>
        nodes
        |> Enum.filter(&(&1.type == :call))
        |> Enum.map(fn node ->
          %{"id" => node.id, "module" => S.safe(node.meta[:module]),
            "function" => S.safe(node.meta[:function]), "owner" => Map.get(owners, node.id)}
        end)
        |> Enum.sort_by(& &1["id"]),
      "local_hook_edges" => edge_records(plugin.analyze(nodes, []), index, owners)
    }
  end

  def analyze_project(paths, plugin) do
    project = Reach.Project.from_sources(Enum.map(paths, &S.fixture!/1), plugins: [plugin])
    nodes = Map.values(project.nodes)
    index = project.nodes
    owners = owner_index(nodes)
    has_hook = function_exported?(plugin, :analyze_project, 3)

    # Explicit project-level hook invocation isolates project routing from the
    # independent RCH-01 module-hook forwarding defect.
    raw_hook = if has_hook, do: plugin.analyze_project(project.modules, nodes, []), else: []
    project_graph =
      Graph.edges(project.graph)
      |> Enum.map(&{&1.v1, &1.v2, &1.label})
      |> MapSet.new()

    %{
      "api" => "Reach.Project.from_sources/2 and #{inspect(plugin)}.analyze_project/3",
      "paths" => paths,
      "node_count" => map_size(project.nodes),
      "selected_plugins" => Enum.map(project.plugins, &inspect/1),
      "has_project_hook" => has_hook,
      "project_hook_edges" => edge_records(raw_hook, index, owners),
      "project_hook_edges_present_in_merged_graph" =>
        Enum.count(raw_hook, &MapSet.member?(project_graph, &1)),
      "caveat" => "Matching graph edges are not proof of unique plugin ownership when labels collide."
    }
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

  def collect do
    local = Map.new(@local_cases, fn {name, path, plugin} ->
      {name, safe_probe(fn -> analyze_file(path, plugin) end)}
    end)

    scopes = %{
      "ash_same_name_project" =>
        safe_probe(fn -> analyze_project(@ash_same, Reach.Plugins.Ash) end),
      "ash_different_name_project" =>
        safe_probe(fn -> analyze_project(@ash_different, Reach.Plugins.Ash) end)
    }

    S.result!(
      %{
        status: "inconclusive",
        classification: "investigation_only_unverified_framework_precision",
        inputs: S.input_records(fixture_paths()),
        analysis_scopes: [
          %{api: "Plugin.analyze/2", scope: "single-file Phoenix/Ecto controls"},
          %{api: "Plugin.analyze_project/3", scope: "multi-file Ash only; Phoenix fallback uses analyze/2"},
          %{api: "Reach.Project.from_sources/2", scope: "merged project graph comparison"}
        ],
        observations: [
          %{"scenario" => "direct_local_hooks", "results" => local},
          %{"scenario" => "project_hooks", "results" => scopes}
        ],
        oracle_expectations: [
          %{rule: "Only treat an observed edge as wrong after verifying semantic target scopes and Reach's declared heuristic contract."},
          %{rule: "The Ecto TestRepo/FakeRepo examples intentionally exercise suffix-based Repo detection, not verified Ecto.Repo behaviour."}
        ],
        diagnostics: [
          %{note: "Phoenix action_fallback edges come from analyze/2; Phoenix project-level analysis does not test that rule. Ash project hooks avoid relying on missing module-local propagation."},
          %{note: "Ash DSL-shaped fixtures are parsed, never compiled. Confirm production-faithful behavior before filing."}
        ]
      },
      "INV-100"
    )
  end

  def run!, do: S.run!("INV-100", &collect/0)
end
