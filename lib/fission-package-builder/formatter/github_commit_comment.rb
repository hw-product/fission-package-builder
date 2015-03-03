require 'fission-package-builder'

module Fission
  module PackageBuilder
    module Formatters

      # Formatter for github kit commit comment
      class GithubCommitComment < Fission::Formatter

        SOURCE = :package_builder
        DESTINATION = :github_kit

        # Format payload and add information for commit comment
        #
        # @param payload [Smash]
        def format(payload)
          if(payload.get(:data, :package_builder, :name))
            pkg = payload[:data][:package_builder]
            origin_info = origin(payload[:brand])
            if(payload[:status].to_s == 'error')
              payload.set(
                :data, :github_kit, :commit_comment, Smash.new(
                  :repository => [
                    payload.get(:data, :code_fetcher, :info, :owner),
                    payload.get(:data, :code_fetcher, :info, :name)
                  ].join('/'),
                  :reference => payload.get(:data, :code_fetcher, :info, :commit_sha),
                  :message => [
                    "[#{origin_info[:application]}] FAILED #{pkg[:name]} build (version: #{pkg[:version]})",
                    "Package building attempt failed!\n\nExtracted error message:\n",
                    "```",
                    "#{extract_chef_stacktrace(payload) || '<unavailable>'}\n",
                    "```",
                    "- #{job_url(payload)}"
                  ].join("\n")
                )
              )
            else
              payload.set(
                :data, :github_kit, :commit_comment, Smash.new(
                  :repository => [
                    payload.get(:data, :code_fetcher, :info, :owner),
                    payload.get(:data, :code_fetcher, :info, :name)
                  ].join('/'),
                  :reference => payload.get(:data, :code_fetcher, :info, :commit_sha),
                  :message => "[#{origin_info[:application]}] New #{pkg[:name]} created (version: #{pkg[:version]})\n\n- #{job_url(payload)}"
                )
              )
            end
          end
        end

      end

    end
  end
end
