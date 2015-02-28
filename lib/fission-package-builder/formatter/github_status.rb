require 'fission-package-builder'

module Fission
  module PackageBuilder
    module Formatters

      class GithubStatus < Fission::Formatter

        SOURCE = :package_builder
        DESTINATION = :github_kit

        def format(payload)
          if(payload[:status].to_s == 'error')
            payload.set(
              :data, :github_kit, :status, Smash.new(
                :repository => payload.get(:data, :code_fetcher, :info, :name),
                :reference => payload.get(:data, :code_fetcher, :info, :commit_sha),
                :state => :failed,
                :extras => {
                  :description => 'Package build failed!',
                  :target_url => job_url(payload)
                }
              )
            )
          else
            payload.set(
              :data, :github_kit, :status, Smash.new(
                :repository => payload.get(:data, :code_fetcher, :info, :name),
                :reference => payload.get(:data, :code_fetcher, :info, :commit_sha),
                :state => :success
              )
            )
          end
        end

      end

    end
  end
end
