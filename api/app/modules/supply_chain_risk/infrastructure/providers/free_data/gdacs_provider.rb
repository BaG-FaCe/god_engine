module SupplyChainRisk
  module Infrastructure
    module Providers
      module FreeData
        # GDACS - Global Disaster Alert and Coordination System (EU/JRC).
        #
        # Publishes earthquakes, floods, cyclones, droughts, wildfires and
        # volcanic activity with an alert level (Green / Orange / Red) and the
        # affected countries. It is the backbone of the early warning feed because
        # it covers all hazard types in a single, free, well documented API.
        #
        # Two capabilities are used:
        #   * `events`  - poll the feed and raise `RiskEvent`s for the affected
        #                 countries, which is what the dashboard warning list shows
        #   * `assess`  - score a single material by whether its origin country is
        #                 currently affected
        class GdacsProvider < Domain::RiskDataProvider
          ENDPOINT = 'https://www.gdacs.org/gdacsapi/api/events/geteventlist/SEARCH'

          ALERT_SEVERITY = { 'Green' => 'low', 'Orange' => 'high', 'Red' => 'critical' }.freeze
          ALERT_SCORES = { 'Green' => 12, 'Orange' => 55, 'Red' => 85 }.freeze
          DEFAULT_SCORE = 8

          EVENT_TYPES = { 'EQ' => 'disaster', 'TC' => 'weather', 'FL' => 'disaster',
                          'DR' => 'weather', 'WF' => 'disaster', 'VO' => 'disaster',
                          'TS' => 'disaster' }.freeze

          LOOKBACK_DAYS = 7

          class << self
            def descriptor
              @descriptor ||= Infrastructure::ProviderCatalogue.find!('gdacs')
            end
          end

          # Recent alerts for the material's origin country.
          def assess(subject)
            code = Support.country_code(subject.origin_country)
            return nil if code.blank?

            alerts = alerts_for(code)
            worst = alerts.max_by { |alert| ALERT_SCORES.fetch(alert[:alert_level], 0) }

            if worst.nil?
              return draft(
                risk_score: DEFAULT_SCORE,
                dimensions: { 'weather' => DEFAULT_SCORE, 'operational' => DEFAULT_SCORE },
                reason: "Keine aktiven GDACS-Warnungen für #{code} in den letzten #{LOOKBACK_DAYS} Tagen",
                data_sources: ['GDACS'],
                confidence: BigDecimal('0.7')
              )
            end

            score = ALERT_SCORES.fetch(worst[:alert_level], DEFAULT_SCORE)
            draft(
              risk_score: score,
              dimensions: { 'weather' => score, 'operational' => score },
              reason: "GDACS #{worst[:alert_level]}-Warnung in #{code}: #{worst[:title]}",
              data_sources: ['GDACS'],
              raw_payload: worst,
              confidence: BigDecimal('0.85')
            )
          end

          # Bulk feed used by the recurring polling job.
          def events(since: LOOKBACK_DAYS.days.ago)
            features = fetch_features(since)

            features.filter_map do |feature|
              properties = feature['properties'] || {}
              geometry = feature['geometry'] || {}

              Domain::EventDraft.build(
                source: key,
                source_event_id: properties['eventid'] || properties['eventId'],
                event_type: EVENT_TYPES.fetch(properties['eventtype'], 'disaster'),
                severity: ALERT_SEVERITY.fetch(properties['alertlevel'], 'medium'),
                title: [properties['eventtype'], properties['name']].compact.join(' - ').presence ||
                       'GDACS-Ereignis',
                description: properties['htmldescription'].to_s.truncate(1000).presence ||
                             properties['description'],
                country_code: Support.country_code(properties['country']),
                occurred_at: parse_time(properties['fromdate']) || Time.current,
                metadata: {
                  alertLevel: properties['alertlevel'],
                  eventType: properties['eventtype'],
                  coordinates: geometry['coordinates'],
                  severityData: properties['severitydata']
                }.compact
              )
            end
          end

          private

          def alerts_for(code)
            fetch_features(LOOKBACK_DAYS.days.ago).filter_map do |feature|
              properties = feature['properties'] || {}
              next unless Support.mentions_country?(properties['country'], code)

              {
                alert_level: properties['alertlevel'] || 'Green',
                title: [properties['eventtype'], properties['name']].compact.join(' '),
                event_id: properties['eventid']
              }
            end
          rescue Shared::Infrastructure::Http::JsonClient::Error => e
            context.log(:warn, 'GDACS-Abfrage fehlgeschlagen', error: e.message)
            []
          end

          def fetch_features(since)
            from = since.to_date.iso8601
            to = Time.current.to_date.iso8601

            context.cached('gdacs', "#{from}:#{to}") do
              body = context.http.get_json(
                ENDPOINT,
                params: {
                  fromDate: from, toDate: to,
                  alertlevel: 'Green;Orange;Red',
                  eventlist: 'EQ;TC;FL;DR;WF;VO;TS'
                },
                provider_key: key
              )
              return [] if body.blank?

              Array(body['features'])
            end
          end

          def parse_time(value)
            return nil if value.blank?

            Time.zone.parse(value.to_s)
          rescue ArgumentError
            nil
          end
        end
      end
    end
  end
end