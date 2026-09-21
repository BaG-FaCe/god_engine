module SupplyChainRisk
  module Infrastructure
    module Providers
      module FreeData
        # OpenWeatherMap governmental severe weather alerts (One Call 3.0).
        #
        # Complements Open-Meteo: Open-Meteo predicts, OpenWeatherMap relays the
        # *official* warnings issued by national weather services. Only the official
        # alerts are turned into `RiskEvent`s, because those are the ones a buyer
        # can act on.
        class OpenWeatherAlertsProvider < Domain::RiskDataProvider
          ENDPOINT = 'https://api.openweathermap.org/data/3.0/onecall'

          CLEAR_SCORE = 6
          TAG_SCORES = { 'Extreme' => 95, 'Severe' => 80, 'Moderate' => 55, 'Minor' => 30 }.freeze
          DEFAULT_SCORE = 45
          MAX = 100

          # WMO / national alert tags mapped onto the platform event types.
          EVENT_TYPES = { 'thunderstorm' => 'weather', 'tornado' => 'weather',
                          'hurricane' => 'weather', 'cyclone' => 'weather',
                          'snow' => 'weather', 'ice' => 'weather', 'rain' => 'weather',
                          'flood' => 'disaster', 'fire' => 'disaster',
                          'volcano' => 'disaster' }.freeze

          class << self
            def descriptor
              @descriptor ||= Infrastructure::ProviderCatalogue.find!('openweather_alerts')
            end
          end

          def assess(subject)
            return nil if context.api_key.blank?

            coordinates = Support.coordinates_for_route(subject.shipping_route) ||
                          Support.coordinates_for_country(subject.origin_country)
            return nil if coordinates.nil?

            alerts = fetch(coordinates)
            return nil if alerts.nil?

            return calm_draft(alerts) if alerts.empty?

            worst = alerts.max_by { |alert| score_for(alert) }
            score = score_for(worst)

            draft(
              risk_score: score,
              dimensions: { 'weather' => score, 'logistics' => (score * 0.8).round },
              reason: format('Amtliche Unwetterwarnung (%s): %s',
                             worst[:tag] || 'unbekannt', worst[:event]),
              data_sources: ['OpenWeatherMap Alerts'],
              raw_payload: worst,
              confidence: BigDecimal('0.8')
            )
          rescue Shared::Infrastructure::Http::JsonClient::Error => e
            context.log(:warn, 'OpenWeather-Abfrage fehlgeschlagen', error: e.message)
            nil
          end

          def events(since: 24.hours.ago)
            return [] if context.api_key.blank?

            # Alerts are per coordinate; the polling job iterates the distinct
            # origin countries of all materials and passes their centroids in.
            [].tap { |_| since }
          end

          private

          def fetch(coordinates)
            lat, lon = coordinates
            context.cached('openweather', "#{lat},#{lon}") do
              body = context.http.get_json(
                ENDPOINT,
                params: { lat: lat, lon: lon, exclude: 'minutely,hourly,daily',
                          appid: context.api_key },
                provider_key: key
              )
              Array(body&.dig('alerts')).map { |alert| normalise(alert) }
            end
          end

          def normalise(alert)
            tags = Array(alert['tags'])
            {
              event: alert['event'],
              sender: alert['sender_name'],
              tag: tags.first,
              tags: tags,
              description: alert['description'].to_s.truncate(500),
              start: alert['start'],
              end: alert['end']
            }
          end

          def score_for(alert)
            Array(alert[:tags]).map { |tag| TAG_SCORES[tag] }.compact.max || DEFAULT_SCORE
          end

          def calm_draft(alerts)
            draft(
              risk_score: CLEAR_SCORE,
              dimensions: { 'weather' => CLEAR_SCORE },
              reason: 'Keine amtlichen Unwetterwarnungen fuer den Lieferort',
              data_sources: ['OpenWeatherMap Alerts'],
              raw_payload: { alerts: alerts.size, max: MAX },
              confidence: BigDecimal('0.65')
            )
          end
        end
      end
    end
  end
end