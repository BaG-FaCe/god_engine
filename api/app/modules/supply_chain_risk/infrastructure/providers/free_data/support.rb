require 'yaml'

module SupplyChainRisk
  module Infrastructure
    module Providers
      module FreeData
        # Shared helpers for the open-data adapters.
        #
        # Open data sources are heterogeneous: some key on ISO-3166 country codes,
        # some on coordinates, some return GeoJSON with free-text country names.
        # Everything is normalised here so each adapter stays small and readable.
        #
        # Reference data (centroids, ports, country names) lives in
        # `config/risk_country_data.yml` so it can be extended without a code change.
        module Support
          DATA_PATH = 'config/risk_country_data.yml'

          class << self
            def centroids
              data['countryCentroids'] || {}
            end

            def ports
              data['portCoordinates'] || {}
            end

            def names
              data['countryNames'] || {}
            end

            def reload!
              @data = nil
            end

            # `"Germany"`, `"de"`, `"DEU"` -> `"DE"`
            def country_code(value)
              return nil if value.blank?

              raw = value.to_s.strip
              return raw.upcase if raw.length == 2

              names[normalise_name(raw)] || raw.upcase[0, 2]
            end

            # UN M49 numeric code for the Comtrade adapter; nil when unknown so the
            # provider reports nothing instead of querying a wrong country.
            def comtrade_code(code)
              iso = country_code(code)
              return nil if iso.blank?

              (data['comtradeCodes'] || {})[iso.to_s]
            end

            def coordinates_for_country(code)
              centroids[country_code(code).to_s]
            end

            # Resolves a free-text shipping route ("CN-SHA -> DE-HAM",
            # "Shanghai to Rotterdam") into coordinates.
            def coordinates_for_route(route)
              return nil if route.blank?

              key = route.to_s.downcase.gsub(/[^a-z]/, '')
              match = ports.find { |port, _| key.include?(port) }
              match&.last
            end

            # True when a free-text blob (e.g. a GeoJSON `country` field) refers to
            # the given ISO code.
            def mentions_country?(text, code)
              return false if text.blank? || code.blank?

              target = code.to_s.upcase
              return true if text.to_s.downcase.include?(target.downcase)

              name = names.key(target)
              name.present? && text.to_s.downcase.include?(name)
            end

            def normalise_name(value)
              value.to_s.downcase.gsub(/[^a-z]/, '')
            end

            private

            def data
              @data ||= begin
                path = Rails.root.join(DATA_PATH)
                File.exist?(path) ? (YAML.safe_load_file(path) || {}) : {}
              end
            end
          end
        end
      end
    end
  end
end