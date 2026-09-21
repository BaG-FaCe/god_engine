require 'yaml'

module SupplyChainRisk
  module Infrastructure
    module Providers
      module FreeData
        # Port congestion indicator.
        #
        # Congestion is the most common cause of a lead time slippage that no
        # supplier is responsible for, so it deserves its own signal instead of
        # being hidden inside a generic logistics score.
        #
        # The score is derived from published average waiting times
        # (config/risk_port_data.yml, refreshable from the UNESCAP / World Bank port
        # waiting time database) and from a forward-looking trend flag.
        class PortCongestionProvider < Domain::RiskDataProvider
          DATA_PATH = 'config/risk_port_data.yml'

          # waitingHours / baselineWaitingHours -> risk score
          RATIO_BANDS = [{ min: 2.5, score: 85 }, { min: 1.8, score: 70 },
                         { min: 1.3, score: 52 }, { min: 1.0, score: 35 }].freeze
          TREND_BONUS = { 'rising' => 15, 'stable' => 0, 'falling' => -10 }.freeze
          BELOW_BASELINE_SCORE = 12
          MAX = 100

          class << self
            def descriptor
              @descriptor ||= Infrastructure::ProviderCatalogue.find!('port_congestion')
            end

            def data
              @data ||= begin
                path = Rails.root.join(DATA_PATH)
                File.exist?(path) ? (YAML.safe_load_file(path) || {}) : {}
              end
            end

            def reload!
              @data = nil
            end
          end

          def assess(subject)
            port = resolve_port(subject.shipping_route)
            return assess_country(subject) if port.nil?

            score = score_for(port)
            draft(
              risk_score: score,
              dimensions: { 'logistics' => score, 'operational' => (score * 0.9).round },
              reason: format('%s: durchschnittlich %.0f h Wartezeit (Basis %.0f h), Trend %s',
                             port['name'], port['waitingHours'].to_f, baseline, port['trend']),
              data_sources: ['UNESCAP/World Bank Hafen-Wartezeiten'],
              raw_payload: port,
              confidence: BigDecimal('0.65')
            )
          end

          private

          def assess_country(subject)
            factor = country_factor(subject.origin_country)
            return nil if factor.nil?

            score = ((factor - 0.7) / 1.1 * 100).round.clamp(0, MAX)
            draft(
              risk_score: score,
              dimensions: { 'logistics' => score },
              reason: format('Laenderspezifischer Kongestionsfaktor %s: %.2f (kein Hafen aufgeloest)',
                             subject.origin_country, factor),
              data_sources: ['UNESCAP/World Bank Hafen-Wartezeiten'],
              raw_payload: { countryFactor: factor },
              confidence: BigDecimal('0.45')
            )
          end

          def resolve_port(route)
            return nil if route.blank?

            key = route.to_s.downcase.gsub(/[^a-z]/, '')
            match = ports.find { |port_key, _| key.include?(port_key) }
            match&.last
          end

          def score_for(port)
            ratio = port['waitingHours'].to_f / baseline
            base = RATIO_BANDS.find { |band| ratio >= band[:min] }&.fetch(:score) || BELOW_BASELINE_SCORE
            base += TREND_BONUS.fetch(port['trend'].to_s, 0) if ratio >= 1.0
            base.clamp(0, MAX)
          end

          def baseline
            (self.class.data['baselineWaitingHours'] || 24).to_f
          end

          def ports
            self.class.data['ports'] || {}
          end

          def country_factor(code)
            (self.class.data['countryCongestion'] || {})[Support.country_code(code).to_s]
          end
        end
      end
    end
  end
end