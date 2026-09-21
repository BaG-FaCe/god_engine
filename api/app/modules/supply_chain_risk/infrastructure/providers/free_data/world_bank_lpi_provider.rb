module SupplyChainRisk
  module Infrastructure
    module Providers
      module FreeData
        # World Bank Logistics Performance Index.
        #
        # The LPI is published every two years and rates a country's trade
        # logistics on a 1 (worst) to 5 (best) scale, with sub-scores for customs,
        # infrastructure, international shipments, logistics competence,
        # tracking/tracing and timeliness.
        #
        # It answers "how capable is the logistics system of the origin country in
        # general?" - the baseline that individual shipment data is compared
        # against. Because it changes only every two years, the response is cached
        # for 24 hours and the adapter is cheap enough to run for every material.
        class WorldBankLpiProvider < Domain::RiskDataProvider
          # Overall LPI score -> risk contribution (0-100).
          # LPI 1.0 is reference "worst", 5.0 "best".
          SCORE_BANDS = [
            { min: 4.2, score: 8 },
            { min: 3.8, score: 18 },
            { min: 3.4, score: 30 },
            { min: 3.0, score: 42 },
            { min: 2.6, score: 55 },
            { min: 2.2, score: 68 }
          ].freeze
          FALLBACK_SCORE = 80

          # Sub-score weights within the logistics dimension.
          SUB_SCORE_WEIGHTS = {
            'customs' => 0.25,
            'infrastructure' => 0.2,
            'international' => 0.2,
            'competence' => 0.15,
            'tracking' => 0.1,
            'timeliness' => 0.1
          }.freeze

          class << self
            def descriptor
              @descriptor ||= Infrastructure::ProviderCatalogue.find!('world_bank_lpi')
            end

            def endpoint
              'https://api.worldbank.org/v2/country/%<country>s/indicator/LP.LPI.OVRL.XQ'
            end
          end

          def assess(subject)
            code = Support.country_code(subject.origin_country)
            return nil if code.blank?

            payload = fetch_indicator(code)
            return nil if payload.nil?

            score = payload[:score]
            return nil if score.nil?

            draft(
              risk_score: SCORE_BANDS.find { |band| score >= band[:min] }&.fetch(:score) || FALLBACK_SCORE,
              dimensions: { 'logistics' => logistics_dimension(score) },
              reason: reason_for(code, score, payload[:year]),
              data_sources: ['World Bank LPI'],
              raw_payload: { country: code, lpi: score, year: payload[:year] },
              confidence: BigDecimal('0.6')
            )
          end

          private

          # The World Bank API returns `[metadata, [ {date:, value:}, ... ] ]`.
          def fetch_indicator(code)
            url = format(self.class.endpoint, country: code)

            context.cached('world_bank_lpi', code) do
              body = context.http.get_json(
                url,
                params: { format: 'json', per_page: 5, mrnev: 1 },
                provider_key: key
              )
              parse(body)
            end
          rescue Shared::Infrastructure::Http::JsonClient::Error => e
            context.log(:warn, 'LPI-Abfrage fehlgeschlagen', error: e.message, country: code)
            nil
          end

          def parse(body)
            rows = Array(body).second
            row = Array(rows).find { |entry| entry.is_a?(Hash) && entry['value'].present? }
            return nil if row.nil?

            { score: row['value'].to_f, year: row['date'].to_i }
          end

          # LPI 1-5 mapped onto 0-100 risk: better logistics, lower risk.
          def logistics_dimension(lpi_score)
            normalised = ((5.0 - lpi_score) / 4.0).clamp(0.0, 1.0)
            (normalised * 100).round
          end

          def reason_for(code, score, year)
            format('Logistics Performance Index für %s: %.2f von 5 (%s)',
                   code, score, year.to_i.positive? ? year : 'aktuell')
          end
        end
      end
    end
  end
end