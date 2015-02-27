require 'fission-package-builder'

module Fission
  module PackageBuilder
    module Formatters

      class GithubComment < Fission::Formatter

        SOURCE = :package_builder
        DESTINATION = :github_comment

        def format(payload)
          pkg = payload[:data][:package_builder]
          origin_info = origin(payload[:brand])
          if(payload[:status].to_s == 'error')
            payload[:data][:github_comment] = {
              :message => [
                "[#{origin_info[:application]}] FAILED #{pkg[:name]} build (version: #{pkg[:version]})",
                "Package building attempt failed!\n\nExtracted error message:\n",
                "```",
                "#{extract_chef_stacktrace(payload) || '<unavailable>'}\n",
                "```",
                "- #{job_url(payload)}"
              ].join("\n")
            }
          else
            payload[:data][:github_comment] = {
              :message => "[#{origin_info[:application]}] New #{pkg[:name]} created (version: #{pkg[:version]})\n\n- #{job_url(payload)}"
            }
          end
        end

      end

    end
  end
end
