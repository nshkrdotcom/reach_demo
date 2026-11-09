defmodule ReachDemo.PluginSDGs.InferredSource do
  def make_changeset(attrs), do: Ecto.Changeset.cast(%{}, attrs, [:name])
end
