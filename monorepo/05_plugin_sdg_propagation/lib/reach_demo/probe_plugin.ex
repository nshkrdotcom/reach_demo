defmodule ReachDemo.PluginSDGs.ProbePlugin do
  @moduledoc "Test-only plugin: separate local and project hooks verify graph construction."
  @behaviour Reach.Plugin
  @local_label :reach_demo_local_probe
  @project_label :reach_demo_project_probe

  def local_label, do: @local_label
  def project_label, do: @project_label

  @impl true
  def analyze(nodes, _opts), do: link(nodes, @local_label)

  @impl true
  def analyze_project(_modules, nodes, _opts), do: link(nodes, @project_label)

  defp link(nodes, label) do
    defs = Enum.filter(nodes, &(&1.type == :function_def))
    origin = Enum.find(defs, &(&1.meta[:name] == :origin and &1.meta[:arity] == 1))
    destination = Enum.find(defs, &(&1.meta[:name] == :destination and &1.meta[:arity] == 1))

    case {origin, destination} do
      {%{id: from}, %{id: to}} -> [{from, to, label}]
      _ -> []
    end
  end
end
