# Generated shared semantic locator. Reach integer IDs are observations, not match keys.
defmodule ReachDemo.Support.Locators do
  @moduledoc "Stable, structure-qualified source locators with explicit ambiguity detection."

  def definitions(project, function_name) do
    project.nodes
    |> Map.values()
    |> Enum.filter(fn n -> n.type == :function_def and n.meta[:name] == function_name end)
    |> Enum.sort_by(& &1.id)
  end

  def entries(project, function_name) do
    project
    |> definitions(function_name)
    |> Enum.flat_map(&walk_definition/1)
    |> Enum.sort_by(&{&1["semantic_locator"], &1["node_id"]})
  end

  defp walk_definition(def_node) do
    mod = ReachDemo.Support.text(def_node.meta[:module])
    name = ReachDemo.Support.text(def_node.meta[:name])
    arity = def_node.meta[:arity]

    heads =
      def_node.children
      |> Enum.filter(&(&1.type == :clause))
      |> Enum.map(fn clause ->
        clause.children |> Enum.take(arity) |> Enum.map(&fingerprint/1) |> Enum.join(";")
      end)

    definition = "#{mod}.#{name}/#{arity} [#{Enum.join(heads, " | ")}]"
    descend(def_node, definition, "function_def", 0)
  end

  defp descend(node, definition, path, depth) when depth <= 30 do
    span = node.source_span || %{}

    row = %{
      "definition_locator" => definition,
      "structural_path" => path,
      "type" => ReachDemo.Support.text(node.type),
      "role" => role(node),
      "fingerprint" => fingerprint(node),
      "semantic_locator" =>
        Enum.join(
          [definition, path, ReachDemo.Support.text(node.type), role(node), fingerprint(node)],
          " :: "
        ),
      "node_id" => node.id,
      "line" => span[:start_line],
      "file" => ReachDemo.Support.rel(span[:file])
    }

    indexed_children =
      node.children
      |> Enum.with_index()
      |> Enum.map(fn {child, index} ->
        typed_index =
          node.children
          |> Enum.take(index)
          |> Enum.count(&(&1.type == child.type))

        {child, "#{path}/#{child.type}[#{typed_index}]"}
      end)

    [
      row
      | Enum.flat_map(indexed_children, fn {child, child_path} ->
          descend(child, definition, child_path, depth + 1)
        end)
    ]
  end

  defp descend(_node, _definition, _path, _depth), do: []

  defp role(node) do
    cond do
      node.type == :var -> ReachDemo.Support.text(node.meta[:binding_role]) || "variable"
      node.type == :function_def -> "definition"
      node.type == :clause -> "clause"
      true -> "expression"
    end
  end

  defp fingerprint(node) do
    meta = node.meta || %{}

    selected =
      [:name, :arity, :function, :module, :kind, :op, :operator, :value, :binding_role]
      |> Enum.flat_map(fn key ->
        if Map.has_key?(meta, key), do: [{key, ReachDemo.Support.safe(meta[key])}], else: []
      end)

    "#{node.type}(#{inspect(selected, limit: 20, printable_limit: 100)})"
  end

  def compare(a, b) do
    a_grouped = Enum.group_by(a, & &1["semantic_locator"])
    b_grouped = Enum.group_by(b, & &1["semantic_locator"])

    (Map.keys(a_grouped) ++ Map.keys(b_grouped))
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(fn locator ->
      left = Map.get(a_grouped, locator, [])
      right = Map.get(b_grouped, locator, [])

      confidence =
        if length(left) == 1 and length(right) == 1, do: "exact", else: "ambiguous_match"

      %{
        "semantic_locator" => locator,
        "a_ids" => Enum.map(left, & &1["node_id"]),
        "b_ids" => Enum.map(right, & &1["node_id"]),
        "a_lines" => Enum.map(left, & &1["line"]),
        "b_lines" => Enum.map(right, & &1["line"]),
        "confidence" => confidence,
        "present_in_both" => left != [] and right != [],
        "id_equal" =>
          if(confidence == "exact", do: hd(left)["node_id"] == hd(right)["node_id"], else: nil)
      }
    end)
  end
end
