defmodule ReachDemo.Frameworks.Ecto.RepoSuffixControl do
  # FakeRepo is not declared as an Ecto.Repo. The suffix-only heuristic can
  # still classify this call as a repository write.
  def fake(attrs) do
    _changeset = Ecto.Changeset.cast(%{}, attrs, [:name])
    ReachDemo.Frameworks.Ecto.FakeRepo.insert(:unrelated)
  end
end
