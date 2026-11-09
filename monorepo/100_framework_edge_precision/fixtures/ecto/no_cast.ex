defmodule ReachDemo.Frameworks.Ecto.Control do
  def write(record), do: ReachDemo.Frameworks.Ecto.TestRepo.insert(record)
end
