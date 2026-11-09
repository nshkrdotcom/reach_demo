defmodule ReachDemo.Frameworks.Ash.ResourceB do
  use Ash.Resource
  actions do
    create :create_user do
      accept [:name]
    end
  end
end
