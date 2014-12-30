require 'fission-package-builder'

module Fission
  module PackageBuilder
    module Formatters

      class GithubStatus < Fission::PayloadFormatter

        SOURCE = :package_builder
        DESTINATION = :github_status

        def format(payload)
          if(payload[:status].to_s == 'error')
            payload[:data].set(:github_status, {
                :state => :failed,
                :description => 'Package build failed',
                :target_url => job_url(payload)
              }
            )
          else
            payload.set(:data, :github_status, :state, :success)
          end
        end

      end

    end
  end
end
