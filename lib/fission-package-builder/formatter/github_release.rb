require 'fission-package-builder'

module Fission
  module PackageBuilder
    module Formatters

      class GithubRelease < Fission::Formatter

        # Source of payload
        SOURCE = :package_builder
        # Destination of payload
        DESTINATION = :github_kit

        # Valid pre-release fragments
        PRERELEASE_STRINGS = [
          'alpha',
          'beta',
          'pre',
          'prerelease'
        ]

        # Check if version is considered pre-release
        #
        # @param verison [String]
        # @return [TrueClass, FalseClass]
        def prerelease?(version)
          !!PRERELEASE_STRINGS.detect do |string|
            version.match(/[^\w]#{string}[^\w]/)
          end
        end

        # Format payload for github_kit to process release
        #
        # @param payload [Smash]
        def format(payload)
          if(payload[:status].to_s != 'error' && payload.get(:data, :package_builder, :name))
            payload.set(:data, :github_kit, :release,
              Smash.new(
                :repository => [
                  payload.get(:data, :code_fetcher, :info, :owner),
                  payload.get(:data, :code_fetcher, :info, :name)
                ].join('/'),
                :reference => payload.get(:data, :code_fetcher, :info, :commit_sha),
                :tag_name => payload.get(:data, :package_builder, :version),
                :name => [
                  payload.get(:data, :package_builder, :name),
                  payload.get(:data, :package_builder, :version)
                ].join('-'),
                :prerelease => prerelease?(payload.get(:data, :package_builder, :version)),
                :body => "Release - #{payload.get(:data, :package_builder, :name)} <#{payload.get(:data, :package_builder, :version)}>",
                :assets => payload.get(:data, :package_builder, :keys)
              )
            )
          end
        end

      end

    end
  end
end
