module SupplyChainRisk
  module Infrastructure
    module Providers
      module FreeData
        # EU TARIC / Access2Markets trade measures.
        #
        # TARIC has no key-free REST interface: the consultation tool is a JSP web
        # application. Rather than scraping HTML (which breaks silently and would
        # be a compliance risk in itself), this adapter is *endpoint configurable*:
        # point it at the Access2Markets/TARIC JSON interface the organisation is
        # entitled to use - or at an internal cache - through
        #
        #   POST /api/v1/risk_providers/eu_taric/configure
        #   config.baseUrl + config.assessmentPath + config.mapping.riskScore
        #
        # Without a configured endpoint the adapter reports nothing and is skipped,
        # which keeps the aggregate honest instead of inventing a duty rate.
        class EuTaricProvider < Domain::RiskDataProvider
          # Duty rate (fraction) to customs risk. A 20 %% anti-dumping duty is a
          # material cost risk, not a rounding error.
          DUTY_BANDS = [{ min: 0.20, score: 80 }, { min: 0.12, score: 60 },
                        { min: 0.06, score: 40 }, { min: 0.02, score: 22 }].freeze
          MEASURE_BONUS = 18
          MAX = 100
          NO_DUTY_SCORE = 10

          class << self
            def descriptor
              @descriptor ||= Infrastructure::ProviderCatalogue.find!('eu_taric')
            end
          end

          def assess(subject)
            return nil if subject.hs_code.blank?
            return nil unless endpoint_configured?

            payload = fetch(subject)
            return nil if payload.blank?

            duty = payload.dig('dutyRate').to_f
            measures = Array(payload['measures'])
            score = [score_for(duty) + (measures.empty? ? 0 : MEASURE_BONUS), MAX].min

            draft(
              risk_score: score,
              dimensions: { 'customs' => score, 'compliance' => (score * 0.8).round },
              reason: reason_for(subject, duty, measures),
              data_sources: ['EU TARIC'],
              raw_payload: payload,
              confidence: BigDecimal('0.75')
            )
          rescue Shared::Infrastructure::Http::JsonClient::Error => e
            context.log(:warn, 'TARIC-Abfrage fehlgeschlagen', error: e.message)
            nil
          end

          private

          def endpoint_configured?
            base_url.present? && assessment_path.present?
          end

          def base_url
            context.config['baseUrl'] || context.config[:baseUrl] || ENV['EU_TARIC_BASE_URL'].presence
          end

          def assessment_path
            context.config['assessmentPath'] || context.config[:assessmentPath] ||
              ENV['EU_TARIC_MEASURES_PATH'].presence
          end

          def fetch(subject)
            context.cached('eu_taric', [subject.hs_code, subject.origin_country].join(':')) do
              context.http.get_json(
                base_url.to_s.chomp('/') + assessment_path.to_s,
                params: { hsCode: subject.hs_code, origin: subject.origin_country,
                          destination: subject.destination_country || 'DE' },
                provider_key: key
              )
            end
          end

          def score_for(duty)
            return NO_DUTY_SCORE if duty <= 0

            DUTY_BANDS.find { |band| duty >= band[:min] }&.fetch(:score) || 15
          end

          def reason_for(subject, duty, measures)
            parts = [format('Zollsatz fuer HS %s aus %s: %.1f %%',
                            subject.hs_code, subject.origin_country, duty * 100)]
            parts << format('%d Handelsmassnahme(n) aktiv', measures.size) if measures.any?
            parts.join(' - ')
          end
        end
      end
    end
  end
end