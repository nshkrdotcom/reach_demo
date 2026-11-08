defmodule ReachDemo.Messages.Investigation do
  @moduledoc "RD-02: empirically compare generic OTP edge scoping with actual actor references."
  alias ReachDemo.Support, as: S

  @same "fixtures/same_file.ex"
  @separate [
    "fixtures/separate/server_a.ex",
    "fixtures/separate/server_b.ex",
    "fixtures/separate/caller.ex"
  ]
  @others ~w(fixtures/upstream_control.ex fixtures/wrong_arity.ex fixtures/guardless.ex fixtures/guarded.ex fixtures/negative_tag.ex)

  def fixture_paths, do: [@same | @separate] ++ @others

  def analyze(paths) do
    # Intentionally *not* source_only: true; this builds each SDG and then merges graphs.
    project = S.project!(paths, source_only: false)
    replies = S.edge_records(project, &S.otp_edge?(&1, :call_reply)) |> S.assert_all_endpoints!()
    messages = S.edge_records(project, &S.message_edge?/1) |> S.assert_all_endpoints!()

    %{
      "project" => project,
      "reply_edges" => replies,
      "message_edges" => messages,
      "nodes" => map_size(project.nodes),
      "graph_edges" => length(S.graph_edges(project))
    }
  end

  def positive_controls! do
    data = analyze(["fixtures/upstream_control.ex"])
    if data["reply_edges"] == [], do: raise("Reach upstream call/reply positive control absent")

    if data["message_edges"] == [],
      do: raise("Reach upstream message-content positive control absent")

    data
  end

  def collect do
    _ = S.qualify!()
    positive = positive_controls!()
    same = analyze([@same])
    separate = analyze(@separate)
    wrong_arity = analyze(["fixtures/wrong_arity.ex"])
    guardless = analyze(["fixtures/guardless.ex"])
    guarded = analyze(["fixtures/guarded.ex"])
    negative_tag = analyze(["fixtures/negative_tag.ex"])

    # Isolate the project-build boundary without changing Reach.Project's graph.
    # Reach builds OTP edges per parsed file, so compare its merged graph with
    # an explicit public OTP pass over the same complete node index.
    same_combined = combined_otp(same["project"])
    separate_combined = combined_otp(separate["project"])

    # CrossProcess is not an alternative call-reply graph generator. Report its
    # independent coupling results and call_target/1's reported target separately.
    same_project = same["project"]

    calls =
      same_project.nodes
      |> Map.values()
      |> Enum.filter(fn n ->
        n.type == :call and n.meta[:module] == GenServer and n.meta[:function] == :call
      end)

    call_targets =
      Enum.map(calls, fn node ->
        %{"call_node_id" => node.id, "call_target" => S.text(Reach.Analysis.call_target(node))}
      end)

    cross_process =
      Reach.OTP.CrossProcess.find_cross_process_coupling(
        Map.values(same_project.nodes),
        all_nodes: Map.values(same_project.nodes)
      )

    same_reply_b = foreign_reply_edges(same["reply_edges"], "ServerB")
    same_content_b = foreign_message_edges(same["message_edges"], "ServerB")
    wrong_arity_decoy = foreign_reply_edges(wrong_arity["reply_edges"], "NotACallback")
    guardless_body_targets = body_local_targets(guardless["message_edges"])
    guarded_body_targets = body_local_targets(guarded["message_edges"])
    all_valid = calls != [] and same["reply_edges"] != [] and same["message_edges"] != []

    status =
      cond do
        !all_valid -> "inconclusive"
        same_reply_b != [] or same_content_b != [] or wrong_arity_decoy != [] -> "reproduced"
        true -> "not_reproduced"
      end

    %{
      status: status,
      analysis_scopes: [
        %{"scope" => "known-positive source file", "build" => "full SDG"},
        %{"scope" => "same source file, three modules", "build" => "full SDG"},
        %{"scope" => "three separate files, merged project graph", "build" => "full SDG"},
        %{"scope" => "standalone control files", "build" => "full SDG"},
        %{
          "scope" => "dedicated cross-process analysis",
          "api" => "Reach.OTP.CrossProcess.find_cross_process_coupling/2"
        }
      ],
      inputs: S.input_records(fixture_paths()),
      observations: [
        compact("upstream_positive", positive),
        compact("same_file", same),
        compact("separate_files_project", separate),
        Map.put(same_combined, "scenario", "combined_otp_same_file"),
        Map.put(separate_combined, "scenario", "combined_otp_separate_files"),
        %{
          "scenario" => "individual_file_otp_passes",
          "files" =>
            Enum.map(@separate, fn file ->
              %{"file" => file, "otp_graph" => local_otp_graph(file)}
            end)
        },
        compact("wrong_arity", wrong_arity),
        compact("guardless", guardless),
        compact("guarded", guarded),
        compact("negative_tag", negative_tag),
        %{
          "scenario" => "dedicated_cross_process",
          "api" => "Reach.OTP.CrossProcess.find_cross_process_coupling/2",
          "call_target_api" => "Reach.Analysis.call_target/1 (exported, undocumented)",
          "call_targets" => call_targets,
          "coupling_findings" => Enum.map(cross_process, &S.safe/1)
        },
        %{"scenario" => "same_file_per_source_otp_graph", "otp_graph" => local_otp_graph(@same)}
      ],
      oracle_expectations: [
        %{
          "message" => "GenServer.call(ServerA, {:lookup, key})",
          "allowed_reply_owner" => "ServerA",
          "disallowed_reply_owner" => "ServerB"
        },
        %{"message" => "handle_call/1", "expected_is_genserver_callback" => false},
        %{
          "message" => "body_local created inside handler",
          "expected_is_pattern_binding" => false
        },
        %{
          "note" =>
            "Possible data-flow overapproximations are not actual runtime deliveries; cross-process coupling is separate."
        }
      ],
      comparisons: [
        %{
          "comparison" => "same_file_wrong_actor",
          "foreign_reply_count" => length(same_reply_b),
          "foreign_message_count" => length(same_content_b),
          "foreign_reply_edges" => same_reply_b,
          "foreign_message_edges" => same_content_b
        },
        %{
          "comparison" => "separate_file_scope",
          "same_file_reply_count" => length(same["reply_edges"]),
          "merged_separate_reply_count" => length(separate["reply_edges"]),
          "same_file_message_count" => length(same["message_edges"]),
          "merged_separate_message_count" => length(separate["message_edges"])
        },
        %{
          "comparison" => "recompute_otp_on_combined_nodes",
          "same_file_manual_reply_count" => length(same_combined["reply_edges"]),
          "same_file_manual_message_count" => length(same_combined["message_edges"]),
          "split_file_manual_reply_count" => length(separate_combined["reply_edges"]),
          "split_file_manual_message_count" => length(separate_combined["message_edges"]),
          "split_file_project_reply_count" => length(separate["reply_edges"]),
          "split_file_project_message_count" => length(separate["message_edges"]),
          "split_file_manual_foreign_reply_count" =>
            length(foreign_reply_edges(separate_combined["reply_edges"], "ServerB")),
          "split_file_manual_foreign_message_count" =>
            length(foreign_message_edges(separate_combined["message_edges"], "ServerB"))
        },
        %{"comparison" => "wrong_arity_handle_call/1", "decoy_edges" => wrong_arity_decoy},
        %{
          "comparison" => "guardless_pattern_collector",
          "body_local_targets_without_guard" => guardless_body_targets,
          "body_local_targets_with_guard" => guarded_body_targets
        }
      ],
      diagnostics: [
        %{
          "source_reference" =>
            "lib/reach/otp/gen_server.ex:add_call_reply_edges/2; lib/reach/otp/coupling.ex:add_message_content_edges/2",
          "warning" =>
            "Graph edges and dedicated cross-process target analysis have distinct scopes and guarantees."
        }
      ]
    }
    |> Map.put(:classification, "precision_limitation")
    |> S.result!("RD-02")
  end

  # Public Reach.OTP API, explicitly given the complete merged node index.
  # This does not modify the project or silently reclassify its graph edges.
  def combined_otp(project) do
    nodes = Map.values(project.nodes)
    graph = Reach.OTP.analyze(nodes, all_nodes: nodes)
    isolated = %{project | graph: graph}

    replies =
      S.edge_records(isolated, &S.otp_edge?(&1, :call_reply))
      |> S.assert_all_endpoints!()

    messages = S.edge_records(isolated, &S.message_edge?/1) |> S.assert_all_endpoints!()

    %{
      "api" => "Reach.OTP.analyze/2 with merged project node index",
      "node_count" => length(nodes),
      "reply_edges" => replies,
      "message_edges" => messages
    }
  end

  defp compact(key, data) do
    %{
      "scenario" => key,
      "node_count" => data["nodes"],
      "full_graph_edges" => data["graph_edges"],
      "reply_edges" => data["reply_edges"],
      "message_edges" => data["message_edges"]
    }
  end

  defp foreign_reply_edges(edges, name) do
    Enum.filter(edges, fn edge ->
      source_owner = get_in(edge, ["source", "owner", "module"]) || ""
      target_owner = get_in(edge, ["target", "owner", "module"]) || ""
      String.ends_with?(source_owner, name) and String.ends_with?(target_owner, "Caller")
    end)
  end

  defp foreign_message_edges(edges, name) do
    Enum.filter(edges, fn edge ->
      target_owner = get_in(edge, ["target", "owner", "module"]) || ""
      String.ends_with?(target_owner, name)
    end)
  end

  defp body_local_targets(edges) do
    Enum.filter(edges, fn e -> get_in(e, ["target", "name"]) == "body_local" end)
  end

  defp local_otp_graph(file) do
    source = File.read!(S.fixture!(file))
    ir = Reach.IR.from_string!(source, file: file)
    g = Reach.OTP.analyze(ir)

    %{
      "api" => "Reach.OTP.analyze/2",
      "edge_count" => length(Graph.edges(g)),
      "otp_labels" => Graph.edges(g) |> Enum.map(&inspect(&1.label)) |> Enum.frequencies()
    }
  end

  def run!, do: S.run!("RD-02", &collect/0)
end
