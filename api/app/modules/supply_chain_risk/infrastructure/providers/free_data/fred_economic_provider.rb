module SupplyChainRisk
  module Infrastructure
    module Providers
      module FreeData
        # FRED (St. Louis Fed) producer price and freight cost indices.
        #
        # Rising input prices are the clearest early indicator of a supplier
        # renegotiation, so the year-on-year change of the Producer Price Index is
        # turned into a price-spike risk. FRED is free with a registered key.
        class FredEconomicProvider < Domain::RiskDataProvider
          ENDPOINT = 'https://api.stlouisfed.org/fred/series/observations'
          # PPI All Commodities - broad enough to apply to any material.
          SERIES_ID = 'PPIACO'
          STABLE_SCORE = 12
          # Year-on-year change (fraction) -> price spike risk.
          CHANGE_BANDS = [{ min: 0.12, score: 80 }, { min: 0.07, score: 60 },
                          { min: 0.03, score: 38 }, { min: 0.0, score: 20 }].freeze

          class << self
            def descriptor
              @descriptor ||= Infrastructure::ProviderCatalogue.find!('fred_economic')
            end
          end

          def assess(subject)
            return nil if context.api_key.blank?

            change = year_over_year_change
            return nil if change.nil?

            score = CHANGE_BANDS.find { |band| change >= band[:min] }&.fetch(:score) || STABLE_SCORE

            draft(
              risk_score: score,
              dimensions: { 'financial' => score },
              reason: format('Erzeugerpreisindex %s: %+.1f %% gegenueber Vorjahr',
                             SERIES_ID, change * 100),
              data_sources: ['FRED (St. Louis Fed)'],
              raw_payload: { seriesId: SERIES_ID, changePct: change.round(4) },
              confidence: BigDecimal('0.5')
            )
          rescue Shared::Infrastructure::Http::JsonClient::Error => e
            context.log(:warn, 'FRED-Abfrage fehlgeschlagen', error: e.message)
            nil
          end

          private

          def year_over_year_change
            observations = fetch_observations
            values = observations.filter_map { |row| row['value'].presence && BigDecimal(row['value']) }
            return nil if values.size < 2

            latest = values.first
            year_ago = values.last
            return nil if year_ago.zero?

            ((latest - year_ago) / year_ago).to_f
          end

          def fetch_observations
            context.cached('fred', SERIES_ID) do
              body = context.http.get_json(
                ENDPOINT,
                params: { series_id: SERIES_ID, api_key: context.api_key,
                          file_type: 'json', sort_order: 'desc', limit: 13 },
                provider_key: key
              )
              Array(body&.dig('observations'))
            end
          end
        end
      end
    end
  end
end