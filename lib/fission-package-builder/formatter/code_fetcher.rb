require 'fission-package-builder'

module Fission
  module PackageBuilder
    module Formatters

      # Format payload using contents provided via code fetcher
      class CodeFetcher < Fission::Formatter

        SOURCE = :code_fetcher
        DESTINATION = :package_builder

        # Format payload and add information for package builder
        #
        # @param payload [Smash]
        def format(payload)
          unless(payload.get(:data, :package_builder, :code_asset))
            if(asset = payload.get(:data, :code_fetcher, :asset))
              payload.set(:data, :package_builder, :code_asset, asset)
            end
          end
        end

      end

    end
  end
end
