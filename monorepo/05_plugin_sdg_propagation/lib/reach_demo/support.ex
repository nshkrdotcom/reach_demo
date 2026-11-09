# Local evidence helper for this standalone Mix project.
defmodule ReachDemo.Support do
  @moduledoc "Version-qualified observations, real Reach graph extraction and deterministic evidence."
  @required_version "2.8.4"
  @valid_statuses ~w(not_run reproduced not_reproduced inconclusive execution_failed)

  def qualify! do
    case Application.load(:reach) do
      :ok -> :ok
      {:error, {:already_loaded, :reach}} -> :ok
      {:error, reason} -> raise "Reach application cannot be loaded: #{inspect(reason)}"
    end

    version = Application.spec(:reach, :vsn) |> to_string()

    if version != @required_version,
      do: raise("Reach version mismatch: #{version} != #{@required_version}")

    lock = Mix.Dep.Lock.read() |> Map.get(:reach)

    {hex_checksum, repo, outer_checksum} =
      case lock do
        {:hex, :reach, "2.8.4", checksum, _managers, _deps, repository, outer} ->
          {checksum, repository, outer}

        {:hex, :reach, "2.8.4", checksum, _managers, _deps, repository} ->
          {checksum, repository, nil}

        other ->
          raise "mix.lock must contain exact Hex Reach 2.8.4; found #{inspect(other)}"
      end

    if !is_binary(hex_checksum) or byte_size(hex_checksum) == 0,
      do: raise("Missing Hex inner checksum for Reach")

    %{
      "reach_version" => version,
      "hex_inner_checksum" => hex_checksum,
      "hex_outer_checksum" => outer_checksum,
      "hex_repository" => to_string(repo),
      "reach_lock_term" => inspect(lock, limit: 12, printable_limit: 350)
    }
  end

  def fixture!(relative) do
    path = Path.expand(relative)
    if !File.regular?(path), do: raise("Missing fixture #{relative}")
    path
  end

  def fixture_sources!(paths) do
    paths = Enum.map(paths, &fixture!/1)

    Enum.each(paths, fn path ->
      case Code.string_to_quoted(File.read!(path), file: path, columns: true) do
        {:ok, _ast} -> :ok
        {:error, reason} -> raise "Fixture cannot be parsed #{path}: #{inspect(reason)}"
      end
    end)

    paths
  end

  def project!(paths, opts \\ []) do
    paths = fixture_sources!(paths)
    project = Reach.Project.from_sources(paths, opts)
    if map_size(project.nodes) == 0, do: raise("Reach returned no nodes for #{inspect(paths)}")
    project
  end

  def graph_edges(project, selector \\ fn _edge -> true end) do
    project.graph
    |> Graph.edges()
    |> Enum.filter(selector)
    |> Enum.sort_by(fn edge -> {inspect(edge.label), edge.v1, edge.v2} end)
  end

  def require_edge_control!(project, selector, reason) do
    matches = graph_edges(project, selector)
    if matches == [], do: raise("Positive-control precondition failed: #{reason}")

    if Enum.any?(matches, fn edge ->
         not Map.has_key?(project.nodes, edge.v1) or not Map.has_key?(project.nodes, edge.v2)
       end),
       do: raise("Positive-control edge has missing Reach IR endpoint: #{reason}")

    matches
  end

  def otp_edge?(edge, label), do: edge.label == label
  def message_edge?(edge), do: match?({:message_content, _}, edge.label)

  def node_owners(project) do
    project.nodes
    |> Map.values()
    |> Enum.filter(&(&1.type == :function_def))
    |> Enum.sort_by(& &1.id)
    |> Enum.reduce(%{}, fn def_node, owners ->
      mod = def_node.meta[:module]
      name = def_node.meta[:name]
      arity = def_node.meta[:arity]

      context = %{
        "module" => text(mod),
        "function" => text(name),
        "arity" => arity,
        "definition" => "#{text(mod)}.#{text(name)}/#{arity}"
      }

      Reach.IR.all_nodes(def_node)
      |> Enum.reduce(owners, fn node, acc -> Map.put_new(acc, node.id, context) end)
    end)
  end

  def node_record(node, owners \\ %{}) do
    if is_nil(node) do
      nil
    else
      span = node.source_span || %{}

      %{
        "id" => node.id,
        "type" => text(node.type),
        "owner" => Map.get(owners, node.id),
        "file" => rel(Map.get(span, :file)),
        "line" => Map.get(span, :start_line),
        "name" => text(node.meta[:name]),
        "role" => text(node.meta[:binding_role]),
        "function" => text(node.meta[:function]),
        "module" => text(node.meta[:module]),
        "value" => safe(node.meta[:value])
      }
    end
  end

  def edge_records(project, selector) do
    owners = node_owners(project)

    graph_edges(project, selector)
    |> Enum.map(fn edge ->
      a = Map.get(project.nodes, edge.v1)
      b = Map.get(project.nodes, edge.v2)

      %{
        "label" => inspect(edge.label),
        "source_id" => edge.v1,
        "target_id" => edge.v2,
        "source_exists" => !is_nil(a),
        "target_exists" => !is_nil(b),
        "source" => node_record(a, owners),
        "target" => node_record(b, owners)
      }
    end)
  end

  def assert_all_endpoints!(records) do
    if Enum.any?(records, fn row ->
         !row["source_exists"] or !row["target_exists"]
       end),
       do: raise("An observed OTP edge refers to a missing Reach IR node")

    records
  end

  def input_records(paths) do
    Enum.map(paths, fn p ->
      path = fixture!(p)
      %{"path" => rel(path), "sha256" => digest(path), "bytes" => File.stat!(path).size}
    end)
  end

  def digest(path) do
    path |> File.read!() |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
  end

  def rel_location(nil), do: nil

  def rel_location(location) when is_binary(location),
    do: String.replace(location, Path.expand("."), ".")

  def rel_location(other), do: text(other)

  def rel(nil), do: nil
  def rel(path) when is_binary(path), do: Path.relative_to_cwd(Path.expand(path))
  def rel(path), do: text(path)

  def text(nil), do: nil
  def text(a) when is_atom(a), do: Atom.to_string(a)
  def text(other), do: to_string(other)

  def safe(term, depth \\ 0)
  def safe(_term, depth) when depth > 30, do: "[max-depth]"
  def safe(nil, _depth), do: nil
  def safe(a, _depth) when is_boolean(a), do: a
  def safe(a, _depth) when is_atom(a), do: Atom.to_string(a)
  def safe(a, _depth) when is_binary(a), do: String.slice(a, 0, 1024)
  def safe(a, _depth) when is_boolean(a) or is_number(a), do: a

  def safe(list, depth) when is_list(list),
    do: Enum.take(list, 250) |> Enum.map(&safe(&1, depth + 1))

  def safe(map, depth) when is_map(map) do
    map
    |> map_value()
    |> Enum.map(fn {k, v} -> {text(k), safe(v, depth + 1)} end)
    |> Map.new()
  end

  def safe(other, _depth), do: inspect(other, limit: 20, printable_limit: 500)

  # Map.from_struct_if_possible/1 is defined below as a local helper rather than extending Map.
  defp map_value(map) when is_struct(map), do: Map.from_struct(map)
  defp map_value(map), do: map

  def result!(params, id) when is_map(params) do
    provenance = qualify!()
    status = Map.fetch!(params, :status)
    if status not in @valid_statuses, do: raise("Unsupported report status: #{inspect(status)}")

    report = %{
      "schema_version" => "1.0",
      "reproduction_id" => id,
      "status" => status,
      "classification" => Map.get(params, :classification, "unverified"),
      "reach_requested_version" => @required_version,
      "reach_resolved_version" => provenance["reach_version"],
      "elixir_version" => System.version(),
      "otp_version" => to_string(:erlang.system_info(:otp_release)),
      "provenance" => provenance,
      "analysis_scopes" => Map.get(params, :analysis_scopes, []),
      "inputs" => Map.get(params, :inputs, []),
      "observations" => Map.get(params, :observations, []),
      "oracle_expectations" => Map.get(params, :oracle_expectations, []),
      "comparisons" => Map.get(params, :comparisons, []),
      "diagnostics" => Map.get(params, :diagnostics, [])
    }

    report |> safe() |> then(&Map.merge(&1, %{"provenance" => provenance}))
  end

  def write!(report, suffix \\ "") do
    id = report["reproduction_id"]
    path = Path.join("evidence", String.downcase(id) <> suffix <> ".json")
    File.mkdir_p!("evidence")
    File.write!(path, JSON.encode!(report) <> "\n")

    IO.puts("#{id}: #{report["status"]}; wrote #{path}")
    report
  end

  def run!(id, fun) when is_function(fun, 0) do
    try do
      report = fun.() |> write!()
      File.rm(Path.join("evidence", String.downcase(id) <> ".failure.json"))
      report
    rescue
      error ->
        diagnostic = Exception.format(:error, error, __STACKTRACE__)
        IO.puts(:stderr, "#{id} failed: #{diagnostic}")
        # Do not manufacture a successful analysis or conceal the real exception.
        failed = %{
          "schema_version" => "1.0",
          "reproduction_id" => id,
          "status" => "execution_failed",
          "classification" => "unverified",
          "reach_requested_version" => @required_version,
          "reach_resolved_version" => nil,
          "elixir_version" => System.version(),
          "otp_version" => to_string(:erlang.system_info(:otp_release)),
          "analysis_scopes" => [],
          "inputs" => [],
          "observations" => [],
          "oracle_expectations" => [],
          "comparisons" => [],
          "diagnostics" => [%{"exception" => String.slice(diagnostic, 0, 7000)}],
          "provenance" => %{"qualification" => "failed or interrupted"}
        }

        write!(failed, ".failure")
        reraise error, __STACKTRACE__
    catch
      kind, reason ->
        # Exits and throws (including failed linked parse tasks) are not rescued
        # by rescue/1. Keep a failure artifact rather than losing all evidence.
        diagnostic = Exception.format(kind, reason, __STACKTRACE__)
        IO.puts(:stderr, "#{id} interrupted: #{diagnostic}")

        failed = %{
          "schema_version" => "1.0",
          "reproduction_id" => id,
          "status" => "execution_failed",
          "classification" => "unverified",
          "reach_requested_version" => @required_version,
          "reach_resolved_version" => nil,
          "elixir_version" => System.version(),
          "otp_version" => to_string(:erlang.system_info(:otp_release)),
          "analysis_scopes" => [],
          "inputs" => [],
          "observations" => [],
          "oracle_expectations" => [],
          "comparisons" => [],
          "diagnostics" => [%{"exception" => String.slice(diagnostic, 0, 7000)}],
          "provenance" => %{"qualification" => "failed or interrupted"}
        }

        write!(failed, ".failure")
        :erlang.raise(kind, reason, __STACKTRACE__)
    end
  end
end
