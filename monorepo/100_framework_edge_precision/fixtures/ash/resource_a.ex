defmodule ReachDemo.Frameworks.Ash.ResourceA do
  use Ash.Resource
  actions do
    create :create_user do
      accept [:name]
    end
  end
end
