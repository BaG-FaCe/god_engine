module SupplyChainRisk
  module Infrastructure
    module Providers
      module FreeData
        # UN Comtrade trade statistics.
        #
        # Answers "how one-sided is the trade relationship behind this lane?" by
        # comparing what the destination country imports from the origin country
        # with what it imports from the whole world (same commodity total, latest
        # complete year). A destination that sources half of its imports of a
        # commodity from one partner is exposed — whether that partner is
        # sanctioned or another region closes its borders.
        #
        # Uses the key-free public preview endpoint (120 requests/hour). The two
        # HTTP calls are cached for 24 hours through the descriptor TTL, so one
        # material costs ~2 upstream requests per day at most.
        class UnComtradeProvider < Domain::RiskDataProvider
          ENDPOINT = 'https://comtradeapi.un.org/public/v1/preview/C/A/HS'

          # Share of the destination's imports of the commodity total coming from
          # the origin country -> risk.
          SHARE_BANDS = [{ min: 0.50, score: 80 }, { min: 0.30, score: 60 },
                         { min: 0.15, score: 40 }, { min: 0.05, score: 22 }].freeze
          MINIMAL_SHARE_SCORE = 10
          # Trade lanes too small to matter are noise, not signal.
          MIN_TRADE_USD = 1_000_000.0

          class << self
            def descriptor
              @descriptor ||= Infrastructure::ProviderCatalogue.find!('un_comtrade')
            end
          end

          def assess(subject)
            origin = Support.country_code(subject.origin_country)
            destination = Support.country_code(subject.destination_country) || 'DE'
            return nil if origin.blank? || origin == destination

            reporter = Support.comtrade_code(destination)
            partner = Support.comtrade_code(origin)
            return nil if reporter.nil? || partner.nil?

            share = import_share(reporter: reporter, partner: partner, period: trade_period)
            return nil if share.nil?

            score = score_for(share)
            draft(
              risk_score: score,
              dimensions: { 'geopolitical' => score, 'logistics' => (score * 0.6).round },
              reason: reason_for(origin, destination, share),
              data_sources: ['UN Comtrade'],
              raw_payload: {
                origin: origin, destination: destination, period: trade_period,
                importShare: share.round(4)
              },
              confidence: BigDecimal('0.55')
            )
          end

          private

          def trade_period
            (Time.current.year - 1).to_s
          end

          def import_share(reporter:, partner:, period:)
            bilateral = fetch(reporter: reporter, partner: partner, period: period)
            return nil if bilateral.nil? || bilateral < MIN_TRADE_USD

            world = fetch(reporter: reporter, partner: 0, period: period)
            return nil if world.nil? || world <= 0

            [bilateral / world, 1.0].min
          rescue Shared::Infrastructure::Http::JsonClient::Error => e
            context.log(:warn, 'Comtrade-Abfrage fehlgeschlagen', error: e.message)
            nil
          end

          def fetch(reporter:, partner:, period:)
            context.cached('un_comtrade', "#{reporter}:#{partner}:#{period}") do
              body = context.http.get_json(
                ENDPOINT,
                params: { reporterCode: reporter, partnerCode: partner, period: period,
                          flowCode: 'M', cmdCode: 'TOTAL' },
                provider_key: key
              )
              total_value(body)
            end
          end

          def total_value(body)
            rows = Array(body && body['data'])
            return nil if rows.empty?

            rows.sum { |row| row['primaryValue'].to_f }
          end

          def score_for(share)
            SHARE_BANDS.find { |band| share >= band[:min] }&.fetch(:score) || MINIMAL_SHARE_SCORE
          end

          def reason_for(origin, destination, share)
            format('UN Comtrade %s: %.1f %% der %s-Importe (Warengesamt) stammen aus %s',
                   trade_period, share * 100, destination, origin)
          end
        end
      end
    end
  end
end
