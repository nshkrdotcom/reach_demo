defmodule ReachDemo.Frameworks.Ecto.Calls do
  # Positive: the changeset result is passed to the Repo write.
  # The typed data tuple is valid schemaless input to Ecto.Changeset.cast/3.
  def connected(attrs) do
    changeset = Ecto.Changeset.cast({%{}, %{name: :string}}, attrs, [:name])
    ReachDemo.Frameworks.Ecto.TestRepo.insert(changeset)
  end

  # Negative: the changeset is unused; the Repo write receives a distinct value.
  def unrelated(attrs, unrelated_record) do
    _changeset = Ecto.Changeset.cast({%{}, %{name: :string}}, attrs, [:name])
    ReachDemo.Frameworks.Ecto.TestRepo.insert(unrelated_record)
  end

  def cast_only(attrs), do: Ecto.Changeset.cast({%{}, %{name: :string}}, attrs, [:name])
end
