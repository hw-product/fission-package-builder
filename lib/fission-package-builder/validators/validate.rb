module Fission
  module PackageBuilder
    module Validators
      class Validate < Fission::Validators::Validate
      end
    end
  end
end

Fission.register(:package_builder, :validators, :validate , Fission::PackageBuilder::Validators::Validate)
