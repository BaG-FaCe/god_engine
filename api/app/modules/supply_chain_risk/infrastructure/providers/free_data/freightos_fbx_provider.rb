module SupplyChainRisk
  module Infrastructure
    module Providers
      module FreeData
        # Freightos Baltic Index (FBX) container spot rates.
        #
        # Spot rates are the market price of the capacity a material needs, which
        # makes them a leading indicator for both cost and availability risk.
        # Requires the free Freightos data key; without it the adapter is skipped.
        class FreightosFbxProvider < Domain::RiskDataProvider
          DEFAULT_BASE_URL = 'https://api.freightos.com'
          DEFAULT_PATH = '/v1/index/fbx'

          STABLE_SCORE = 15
          # Relative change against the previous period -> risk.
          CHANGE_BANDS = [{ min: 0.30, score: 85 }, { min: 0.18, score: 68 },
                          { min: 0.08, score: 48 }, { min: 0.03, score: 30 }].freeze
          FALLING_DISCOUNT = 12

          # Trade lane by origin region, matching the FBX product structure.
          LANES = { 'CN' => 'FBX01', 'KR' => 'FBX01', 'JP' => 'FBX01',
                    'US' => 'FBX03', 'BR' => 'FBX11', 'ZA' => 'FBX12' }.freeze

          class << self
            def descriptor
              @descriptor ||= Infrastructure::ProviderCatalogue.find!('freightos_fbx')
            end
          end

          def assess(subject)
            return nil if context.api_key.blank?

            lane = lane_for(subject.origin_country)
            payload = fetch(lane)
            return nil if payload.blank?

            change = payload[:change]
            score = score_for(change)

            draft(
              risk_score: score,
              dimensions: { 'logistics' => score, 'financial' => (score * 0.85).round },
              reason: reason_for(lane, change),
              data_sources: ['Freightos Baltic Index'],
              raw_payload: payload,
              confidence: BigDecimal('0.6')
            )
          rescue Shared::Infrastructure::Http::JsonClient::Error => e
            context.log(:warn, 'FBX-Abfrage fehlgeschlagen', error: e.message)
            nil
          end

          private

          def lane_for(code)
            LANES[Support.country_code(code).to_s] || 'FBX01'
          end

          def fetch(lane)
            context.cached('freightos', lane) do
              body = context.http.get_json(
                base_url + path,
                params: { index: lane, apiKey: context.api_key },
                provider_key: key
              )
              parse(body)
            end
          end

          def parse(body)
            return nil if body.blank?

            points = Array(body['data'] || body['indices'])
            latest = points.first || body
            previous = points.second

            current = latest['value'] || latest['price']
            prior = previous && (previous['value'] || previous['price'])
            return nil if current.nil?

            { lane: latest['index'] || body['index'], current: current.to_f,
              change: prior.to_f.zero? ? 0.0 : (current.to_f - prior.to_f) / prior.to_f }
          end

          def score_for(change)
            band = CHANGE_BANDS.find { |entry| change >= entry[:min] }
            return band[:score] if band

            change.negative? ? [STABLE_SCORE - FALLING_DISCOUNT, 0].max : STABLE_SCORE
          end

          def reason_for(lane, change)
            format('FBX %s: Spotraten %+.1f %% gegenueber Vorperiode', lane, change * 100)
          end

          def base_url
            (context.config['baseUrl'] || ENV['FREIGHTOS_BASE_URL'].presence || DEFAULT_BASE_URL).to_s.chomp('/')
          end

          def path
            context.config['assessmentPath'] || ENV['FREIGHTOS_INDEX_PATH'].presence || DEFAULT_PATH
          end
        end
      end
    end
  end
end