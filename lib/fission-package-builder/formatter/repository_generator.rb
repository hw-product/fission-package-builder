require 'fission-package-builder'

module Fission
  module PackageBuilder
    module Formatters

      # Format payload for repository generation
      class RepositoryGenerator < Fission::Formatter

        SOURCE = :package_builder
        DESTINATION = :repository_generator

        # Format payload and add information for package builder
        #
        # @param payload [Smash]
        def format(payload)
          if(payload.get(:data, :package_builder, :categorized))
            payload.set(:data, :repository_generator, :add,
              [payload.get(:data, :package_builder, :categorized)]
            )
          end
        end

      end

    end
  end
end
