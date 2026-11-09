defmodule ReachDemo.Frameworks.Ash.ResourceOther do
  use Ash.Resource
  actions do
    create :update_user do
      accept [:name]
    end
  end
end
