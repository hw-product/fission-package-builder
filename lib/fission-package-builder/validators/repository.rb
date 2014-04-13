module Fission
  module PackageBuilder
    module Validators
      class Repository < Fission::Validators::Repository
      end
    end
  end
end

Fission.register(:package_builder, :validators, :repository, Fission::PackageBuilder::Validators::Repository)
