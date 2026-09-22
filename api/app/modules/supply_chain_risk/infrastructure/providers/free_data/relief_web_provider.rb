module SupplyChainRisk
  module Infrastructure
    module Providers
      module FreeData
        # ReliefWeb disasters feed (UN OCHA).
        #
        # GDACS answers "is there a hazard right now?" with alert levels. ReliefWeb
        # answers the complementary question "is a humanitarian emergency ongoing in
        # that country?", including slow-onset crises (drought, food insecurity,
        # conflict) that no earthquake or cyclone feed reports.
        #
        # ReliefWeb requires an *approved appname* (free registration at
        # https://apidoc.reliefweb.int/parameters#appname). Until one is configured
        # via RELIEFWEB_APPNAME / config.appname, the upstream answers 403 and the
        # adapter degrades to "no signal" instead of failing the polling job.
        #
        # Both the per-material assessment and the bulk `events` feed are supported,
        # so the polling job can raise early-warning events for every affected
        # country without a second HTTP call.
        class ReliefWebProvider < Domain::RiskDataProvider
          ENDPOINT = 'https://api.reliefweb.int/v2/disasters'

          # ReliefWeb `status` -> severity. "alert" is a newly declared emergency,
          # "ongoing" a running one, "past" is history and carries little signal.
          STATUS_SEVERITY = {
            'alert' => 'critical', 'ongoing' => 'high', 'past' => 'low', 'archive' => 'low'
          }.freeze
          STATUS_SCORES = { 'alert' => 78, 'ongoing' => 55, 'past' => 10, 'archive' => 10 }.freeze
          DEFAULT_SCORE = 8

          LOOKBACK_DAYS = 30
          LIMIT = 100

          class << self
            def descriptor
              @descriptor ||= Infrastructure::ProviderCatalogue.find!('reliefweb')
            end
          end

          # Risk contribution of ongoing disasters in the material's origin country.
          def assess(subject)
            code = Support.country_code(subject.origin_country)
            return nil if code.blank?

            worst = disasters_for(code).max_by { |disaster| STATUS_SCORES.fetch(disaster[:status], 0) }

            if worst.nil?
              return draft(
                risk_score: DEFAULT_SCORE,
                dimensions: { 'operational' => DEFAULT_SCORE, 'geopolitical' => DEFAULT_SCORE },
                reason: "Keine aktiven ReliefWeb-Katastrophen fuer #{code} " \
                        "(letzte #{LOOKBACK_DAYS} Tage)",
                data_sources: ['ReliefWeb (OCHA)'],
                confidence: BigDecimal('0.75')
              )
            end

            score = STATUS_SCORES.fetch(worst[:status], DEFAULT_SCORE)
            draft(
              risk_score: score,
              dimensions: {
                'operational' => score,
                'geopolitical' => (score * 0.85).round,
                'weather' => (score * 0.7).round
              },
              reason: "ReliefWeb #{worst[:status]}: #{worst[:name]} in #{code}",
              data_sources: ['ReliefWeb (OCHA)'],
              raw_payload: worst,
              confidence: BigDecimal('0.8')
            )
          end

          # Bulk feed used by the recurring polling job.
          def events(since: LOOKBACK_DAYS.days.ago)
            fetch_disasters(since).filter_map do |record|
              fields = record['fields'] || {}
              name = fields['name'].to_s
              next if name.blank? # a disaster without a name is not actionable

              country = primary_country(fields)
              Domain::EventDraft.build(
                source: key,
                source_event_id: record['id'] || fields['url'],
                event_type: event_type(fields),
                severity: STATUS_SEVERITY.fetch(fields['status'].to_s, 'medium'),
                title: "ReliefWeb: #{name}",
                description: Array(fields['description']).compact.join(' ').truncate(1000).presence,
                country_code: Support.country_code((country && (country['iso3'] || country['name']))),
                occurred_at: parse_time(fields['date']) || Time.current,
                metadata: {
                  status: fields['status'],
                  primaryType: primary_type(fields),
                  sources: Array(fields['source']).map { |entry| entry['shortname'] }.compact,
                  url: fields['url']
                }.compact
              )
            end
          end

          # ReliefWeb is queried live and cached in Solid Cache; nothing is mirrored
          # into the database, but the flag documents that the polling job may call it.
          def pollable?
            true
          end

          # --- private helpers ---

          private

          def disasters_for(code)
            fetch_disasters(LOOKBACK_DAYS.days.ago).filter_map do |record|
              fields = record['fields'] || {}
              country = primary_country(fields)
              next unless country_matches?(fields, country, code)

              { status: fields['status'].to_s, name: fields['name'].to_s,
                disaster_id: record['id'], primary_type: primary_type(fields) }
            end
          rescue Shared::Infrastructure::Http::JsonClient::Error => e
            context.log(:warn, 'ReliefWeb-Abfrage fehlgeschlagen', error: e.message)
            []
          end

          def fetch_disasters(since)
            from = since.to_date.iso8601

            context.cached('reliefweb', from) do
              # POST bodies are the documented ReliefWeb v1 interface. The appname
              # must travel as a POST field (a query string yields HTTP 410).
              body = context.http.post_json(
                ENDPOINT,
                payload: {
                  appname: ENV.fetch('RELIEFWEB_APPNAME', 'god-engine-risk-intelligence'),
                  profile: 'list',
                  limit: LIMIT,
                  sort: ['date:desc'],
                  filter: { field: 'date', value: { from: from }, operator: 'within' },
                  fields: { include: %w[id name status date url primary_type primary_country
                                       description source country] }
                },
                headers: { 'Content-Type' => 'application/json' },
                provider_key: key
              )
              Array(body && body['data'])
            end
          end

          def country_matches?(fields, primary, code)
            return true if primary && Support.country_code(primary['iso3'] || primary['name']) == code

            Array(fields['country']).any? do |entry|
              Support.country_code(entry['iso3'] || entry['name']) == code
            end
          end

          def primary_country(fields)
            fields['primary_country'].is_a?(Hash) ? fields['primary_country'] : nil
          end

          def primary_type(fields)
            Array(fields['primary_type']).first
          end

          # Drought, epidemic, conflict ... are not weather; map the humanitarian
          # type onto the event taxonomy used by the dashboard.
          def event_type(fields)
            type = primary_type(fields).to_s.downcase
            return 'weather' if type.include?('flood') || type.include?('storm') ||
                                type.include?('drought') || type.include?('cyclone')
            return 'disaster' if type.include?('earthquake') || type.include?('volcano') ||
                                 type.include?('fire') || type.include?('landslide')

            'operational'
          end

          # ReliefWeb returns Unix epoch seconds; tolerate ISO strings as well.
          def parse_time(value)
            return nil if value.blank?

            Time.zone.at(Integer(value))
          rescue ArgumentError, TypeError
            begin
              Time.zone.parse(value.to_s)
            rescue ArgumentError, TypeError
              nil
            end
          end
        end
      end
    end
  end
end
