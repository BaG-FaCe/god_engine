module SupplyChainRisk
  module Infrastructure
    module Providers
      module FreeData
        # USGS Earthquake Hazards Program.
        #
        # Complements GDACS for the earthquake hazard specifically: GDACS reports
        # *alerts*, USGS reports *measurements* (magnitude, depth, distance to the
        # nearest settlement). The feed needs no key and no registration, which
        # makes it the most reliable sensor in the whole stack.
        #
        # The magnitude threshold is configurable because a magnitude 4.5 event is
        # irrelevant for electronics assembly but critical for a steel mill.
        class UsgsEarthquakeProvider < Domain::RiskDataProvider
          ENDPOINT = 'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/%<window>s.geojson'

          # Available windows offered by USGS.
          WINDOWS = { hour: 'all_hour', day: 'all_day', week: '4.5_week', month: '4.5_month' }.freeze

          # Magnitude -> risk score. Below the threshold the event is ignored.
          MAGNITUDE_BANDS = [
            { min: 7.0, score: 95, severity: 'critical' },
            { min: 6.0, score: 80, severity: 'critical' },
            { min: 5.5, score: 65, severity: 'high' },
            { min: 5.0, score: 50, severity: 'high' },
            { min: 4.5, score: 35, severity: 'medium' }
          ].freeze

          DEFAULT_WINDOW = :week
          DEFAULT_SCORE = 5
          # Radius in degrees (~111 km per degree) within which an epicentre is
          # considered to affect the sourcing region.
          IMPACT_RADIUS_DEGREES = 5.0

          class << self
            def descriptor
              @descriptor ||= Infrastructure::ProviderCatalogue.find!('usgs_earthquake')
            end

            def window
              WINDOWS.fetch(ENV.fetch('USGS_WINDOW', DEFAULT_WINDOW.to_s).to_sym, '4.5_week')
            end
          end

          def assess(subject)
            coordinates = Support.coordinates_for_route(subject.shipping_route) ||
                          Support.coordinates_for_country(subject.origin_country)
            return nil if coordinates.nil?

            relevant = nearby_earthquakes(coordinates)

            if relevant.empty?
              return draft(
                risk_score: DEFAULT_SCORE,
                dimensions: { 'weather' => DEFAULT_SCORE, 'operational' => DEFAULT_SCORE },
                reason: 'Keine relevanten Erdbeben im Umfeld des Lieferorts',
                data_sources: ['USGS'],
                confidence: BigDecimal('0.7')
              )
            end

            worst = relevant.max_by { |quake| quake[:magnitude] }
            band = MAGNITUDE_BANDS.find { |entry| worst[:magnitude] >= entry[:min] }

            draft(
              risk_score: band[:score],
              dimensions: { 'weather' => band[:score], 'operational' => band[:score] },
              reason: format('Erdbeben der Stärke %.1f im Umfeld (%s)', worst[:magnitude], worst[:place]),
              data_sources: ['USGS'],
              raw_payload: worst,
              confidence: BigDecimal('0.9')
            )
          end

          def events(since: 7.days.ago)
            earthquakes.filter_map do |quake|
              next if quake[:occurred_at].nil? || quake[:occurred_at] < since

              band = MAGNITUDE_BANDS.find { |entry| quake[:magnitude] >= entry[:min] }
              next if band.nil?

              Domain::EventDraft.build(
                source: key,
                source_event_id: quake[:id],
                event_type: 'disaster',
                severity: band[:severity],
                title: format('Erdbeben M %.1f - %s', quake[:magnitude], quake[:place]),
                description: "Tiefe #{quake[:depth_km]} km, USGS-ID #{quake[:id]}",
                country_code: nil,
                occurred_at: quake[:occurred_at],
                metadata: { magnitude: quake[:magnitude], coordinates: quake[:coordinates] }
              )
            end
          end

          private

          def nearby_earthquakes(coordinates)
            lat, lon = coordinates
            earthquakes.select { |quake| within_radius?(quake[:coordinates], lat, lon) }
          rescue Shared::Infrastructure::Http::JsonClient::Error => e
            context.log(:warn, 'USGS-Abfrage fehlgeschlagen', error: e.message)
            []
          end

          def within_radius?(quake_coordinates, lat, lon)
            return false if quake_coordinates.nil?

            quake_lon, quake_lat = quake_coordinates
            (quake_lat.to_f - lat).abs <= IMPACT_RADIUS_DEGREES &&
              (quake_lon.to_f - lon).abs <= IMPACT_RADIUS_DEGREES * 1.5
          end

          def earthquakes
            context.cached('usgs', self.class.window) do
              body = context.http.get_json(
                format(ENDPOINT, window: self.class.window),
                provider_key: key
              )
              Array(body['features']).map { |feature| normalise(feature) }
            end
          end

          def normalise(feature)
            properties = feature['properties'] || {}
            geometry = feature['geometry'] || {}

            {
              id: feature['id'] || properties['code'],
              magnitude: properties['mag'].to_f,
              place: properties['place'],
              occurred_at: parse_time(properties['time']),
              coordinates: geometry['coordinates']&.first(2)&.reverse,
              depth_km: geometry['coordinates']&.third
            }
          end

          # USGS reports epoch milliseconds.
          def parse_time(value)
            return nil if value.blank?

            Time.zone.at(value.to_i / 1000.0)
          end
        end
      end
    end
  end
end