require 'fission-package-builder'

module Fission
  module PackageBuilder
    module Formatters

      class Mail < Fission::Formatter

        SOURCE = :package_builder
        DESTINATION = :mail

        def format(payload)
          pkg = payload[:data][:package_builder]
          dest_email = payload.fetch(:data, :package_builder, :notify,
            payload.fetch(:data, :format, :repository, :owner_email,
              payload.get(:data, :format, :repository, :user_email)
            )
          )
          origin_info = origin(payload[:brand])
          details = File.join(
            payload.get(:data, :format, :repository, :url),
            pkg[:version].to_s
          )
          notify = {
            :destination => {
              :email => dest_email
            },
            :origin => {
              :email => origin_info[:email],
              :name => origin_info[:name]
            }
          }
          if(payload[:status].to_s == 'error')
            error_message = extract_chef_stacktrace(payload)
            notify.merge!(
              :subject => "[#{origin_info[:application]}] FAILED #{pkg[:name]} build (version: #{pkg[:version]})",
              :message => "Package building attempt failed!\n\nExtracted error message:\n\n#{error_message || '<unavailable>'}\n\n- #{job_url(payload)}",
              :html => false
            )
          else
            notify.merge!(
              :subject => "[#{origin_info[:application]}] New #{pkg[:name]} created (version: #{pkg[:version]})",
              :message => "A new package has been built from the #{pkg[:name]} repository.\n\nRelease: #{pkg[:name]}-#{pkg[:version]}\nDetails: #{details}\n",
              :html => false
            )
          end
          payload[:data][:notification_email] = notify

        end

      end

    end
  end
end
