require 'fission-package-builder'

module Fission
  module PackageBuilder
    module Formatters

      class Slack < Fission::Formatter

        SOURCE = :package_builder
        DESTINATION = :slack

        def format(payload)
          if(payload.get(:data, :package_builder, :keys))
            pkg = payload[:data][:package_builder]
            origin_info = origin(payload[:brand])
            if(payload[:status].to_s == 'error')
              payload.set(
                :data, :slack, :messages, [
                  Smash.new(
                    :message => [
                      "[#{origin_info[:application]}] FAILED #{pkg[:name]} build (version: #{pkg[:version]})",
                      "Package building attempt failed!\n\nExtracted error message:\n",
                      "```",
                      "#{extract_chef_stacktrace(payload) || '<unavailable>'}\n",
                      "```",
                      "- #{job_url(payload)}"
                    ].join("\n"),
                    :color => 'danger'
                  )
                ]
              )
            else
              payload.set(
                :data, :slack, :messages, [
                  :message => "[#{origin_info[:application]}] New #{pkg[:name]} created (version: #{pkg[:version]})\n\n- #{job_url(payload)}",
                  :color => 'good'
                ]
              )
            end
          end
        end

      end

    end
  end
end
