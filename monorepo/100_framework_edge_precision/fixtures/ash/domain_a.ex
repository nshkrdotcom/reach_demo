defmodule ReachDemo.Frameworks.Ash.DomainA do
  use Ash.Domain

  # Ash 3 domain-level code interfaces belong INSIDE a resource declaration.
  resources do
    resource ReachDemo.Frameworks.Ash.ResourceA do
      define :create_user, action: :create_user
    end
  end
end
