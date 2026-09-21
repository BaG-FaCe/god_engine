module SupplyChainRisk
  module Infrastructure
    module Providers
      module FreeData
        # Open-Meteo: key-free weather and severe-weather signals.
        #
        # Scored from wind gusts and precipitation along the origin/destination so
        # a storm-prone route raises the logistics dimension before the shipment
        # is even booked.
        class OpenMeteoProvider < Domain::RiskDataProvider
          ENDPOINT = %q(https://api.open-meteo.com/v1/forecast)
          GUST_BANDS = [{ min: 90, score: 85 }, { min: 75, score: 65 },
                        { min: 60, score: 45 }, { min: 45, score: 25 }].freeze
          RAIN_BANDS = [{ min: 50, score: 70 }, { min: 25, score: 45 }].freeze
          CALM_SCORE = 8

          class << self
            def descriptor
              @descriptor ||= Infrastructure::ProviderCatalogue.find!('open_meteo')
            end
          end

          def assess(subject)
            coordinates = Support.coordinates_for_route(subject.shipping_route) ||
                          Support.coordinates_for_country(subject.origin_country)
            return nil if coordinates.nil?

            forecast = fetch(coordinates)
            return nil if forecast.nil?

            gust = forecast[:gust_kmh].to_f
            rain = forecast[:precipitation_mm].to_f
            score = [score_for(GUST_BANDS, gust), score_for(RAIN_BANDS, rain)].max || CALM_SCORE

            draft(
              risk_score: score,
              dimensions: { 'weather' => score, 'logistics' => (score * 0.7).round },
              reason: format('Wetterlage %s: Boeen %.0f km/h, Niederschlag %.0f mm',
                             subject.origin_country, gust, rain),
              data_sources: ['Open-Meteo'],
              raw_payload: forecast,
              confidence: BigDecimal('0.6')
            )
          end

          private

          def score_for(bands, value)
            bands.find { |band| value >= band[:min] }&.fetch(:score)
          end

          def fetch(coordinates)
            lat, lon = coordinates
            context.cached('open_meteo', "#{lat},#{lon}") do
              body = context.http.get_json(
                ENDPOINT,
                params: { latitude: lat, longitude: lon, timezone: 'auto', forecast_days: 3,
                          daily: 'precipitation_sum,wind_gusts_10m_max' },
                provider_key: key
              )
              daily = body&.dig('daily') || {}
              { gust_kmh: Array(daily['wind_gusts_10m_max']).compact.max,
                precipitation_mm: Array(daily['precipitation_sum']).compact.max }
            end
          rescue Shared::Infrastructure::Http::JsonClient::Error => e
            context.log(:warn, 'Open-Meteo-Abfrage fehlgeschlagen', error: e.message)
            nil
          end
        end
      end
    end
  end
end