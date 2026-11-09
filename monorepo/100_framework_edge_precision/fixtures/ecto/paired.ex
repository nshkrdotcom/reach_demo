defmodule ReachDemo.Frameworks.Ecto.Calls do
  # Positive: a returned changeset is passed to the Repo write.
  def connected(attrs) do
    changeset = Ecto.Changeset.cast(%{}, attrs, [:name])
    ReachDemo.Frameworks.Ecto.TestRepo.insert(changeset)
  end

  # Negative: the changeset is unused by the Repo write.
  def unrelated(attrs, unrelated_record) do
    _changeset = Ecto.Changeset.cast(%{}, attrs, [:name])
    ReachDemo.Frameworks.Ecto.TestRepo.insert(unrelated_record)
  end

  def cast_only(attrs), do: Ecto.Changeset.cast(%{}, attrs, [:name])
end
