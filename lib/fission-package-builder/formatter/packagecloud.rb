require 'fission-package-builder'

module Fission
  module PackageBuilder
    module Formatters

      # Format payload for packagecloud
      class Packagecloud < Fission::Formatter

        # Origin of payload
        SOURCE = :package_builder
        # Destination of payload
        DESTINATION = :packagecloud

        # Distro mappings based on package extensions
        # @note fetched and formatted from this base
        #   JSON file: https://packagecloud.io/api/v1/distributions.json
        # @todo Need to adjust the redhat/centos name and versioning junk
        DISTRO_MAPPINGS = {
          "deb" => {
            "ubuntu_410" => "ubuntu/warty",
            "ubuntu_504" => "ubuntu/hoary",
            "ubuntu_510" => "ubuntu/breezy",
            "ubuntu_606" => "ubuntu/dapper",
            "ubuntu_610" => "ubuntu/edgy",
            "ubuntu_704" => "ubuntu/feisty",
            "ubuntu_710" => "ubuntu/gutsy",
            "ubuntu_804" => "ubuntu/hardy",
            "ubuntu_810" => "ubuntu/intrepid",
            "ubuntu_904" => "ubuntu/jaunty",
            "ubuntu_910" => "ubuntu/karmic",
            "ubuntu_1004" => "ubuntu/lucid",
            "ubuntu_1010" => "ubuntu/maverick",
            "ubuntu_1104" => "ubuntu/natty",
            "ubuntu_1110" => "ubuntu/oneiric",
            "ubuntu_1204" => "ubuntu/precise",
            "ubuntu_1210" => "ubuntu/quantal",
            "ubuntu_1304" => "ubuntu/raring",
            "ubuntu_1310" => "ubuntu/saucy",
            "ubuntu_1404" => "ubuntu/trusty",
            "ubuntu_1410" => "ubuntu/utopic",
            "ubuntu_1504" => "ubuntu/vivid",
            "debian_40" => "debian/etch",
            "debian_50" => "debian/lenny",
            "debian_60" => "debian/squeeze",
            "debian_70" => "debian/wheezy",
            "debian_80" => "debian/jessie",
            "debian_90" => "debian/stretch",
            "debian_100" => "debian/buster",
            "any_" => "any/any"
          },
          "rpm" => {
            "el_50" => "el/5",
            "el_60" => "el/6",
            "el_70" => "el/7",
            "fedora_140" => "fedora/14",
            "fedora_150" => "fedora/15",
            "fedora_160" => "fedora/16",
            "fedora_170" => "fedora/17",
            "fedora_180" => "fedora/18",
            "fedora_190" => "fedora/19",
            "fedora_200" => "fedora/20",
            "fedora_210" => "fedora/21",
            "fedora_220" => "fedora/22",
            "fedora_230" => "fedora/23",
            "scientific_50" => "scientific/5",
            "scientific_60" => "scientific/6",
            "scientific_70" => "scientific/7",
            "ol_50" => "ol/5",
            "ol_60" => "ol/6",
            "ol_70"=>"ol/7"
          }
        }

        # Package file extensions that do not require distro
        RAW_EXTENSIONS = ['.gem']
        # Package file extensions that require distro
        DISTRO_EXTENSIONS = ['.deb', '.rpm']

        # Format payload and add information for packagecloud
        #
        # @param payload [Smash]
        def format(payload)
          if(payload.get(:data, :package_builder, :keys))
            pkgs = payload.get(:data, :package_builder, :keys).map do |pkg|
              if(RAW_EXTENSIONS.include?(File.extname(pkg)))
                Smash.new(:path => pkg)
              end
            end.compact
            payload.fetch(:data, :package_builder, :categorized, {}).each do |d_name, d_info|
              d_info.each do |d_version, d_pkgs|
                d_pkgs.each do |pkg|
                  if(DISTRO_EXTENSIONS.include?(File.extname(pkg)))
                    distro = DISTRO_MAPPINGS[File.extname(pkg).sub('.', '')].map do |k,v|
                      v if k.start_with?("#{d_name}_#{d_version.tr('.', '')}")
                    end.compact.first
                    if(distro)
                      pkgs.push(
                        Smash.new(
                          :path => pkg,
                          :distro_description => distro
                        )
                      )
                    end
                  end
                end
              end
            end
            unless(pkgs.empty?)
              payload.set(:data, :packagecloud, :packages, pkgs)
            end
          end
        end

      end

    end
  end
end
