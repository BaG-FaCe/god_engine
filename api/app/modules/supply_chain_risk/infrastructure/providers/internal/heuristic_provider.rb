module SupplyChainRisk
  module Infrastructure
    module Providers
      module Internal
        # The built-in heuristic risk model.
        #
        # It answers "how risky is this material based on what we already know
        # about it?" using only project-internal data: planned lead time, transport
        # mode, freight rate trend, historical delivery performance, single
        # sourcing and supplier rating.
        #
        # Why this matters: it guarantees the risk module produces a usable traffic
        # light on day one - before any commercial data contract - and it remains
        # the fallback whenever every external provider is unreachable or rate
        # limited. Its `confidence` is capped well below 1.0 so an external answer
        # always outranks it during aggregation.
        class HeuristicProvider < Domain::RiskDataProvider
          MAX = 100
          CONFIDENCE = BigDecimal('0.45')

          WEATHER_KEYWORDS = %w[weather storm flood hurricane cyclone typhoon snow
                                frost hail drought heat].freeze

          LEAD_TIME_SCORES = [
            { max_days: 7, score: 5 },
            { max_days: 14, score: 15 },
            { max_days: 30, score: 30 },
            { max_days: 45, score: 45 },
            { max_days: 60, score: 60 },
            { max_days: 90, score: 75 }
          ].freeze
          LEAD_TIME_FALLBACK = 90

          TRANSPORT_MODE_FACTORS = {
            'air' => -10, 'road' => 2, 'rail' => 0, 'sea' => 8, 'multimodal' => 5
          }.freeze

          FREIGHT_TREND_FACTORS = {
            'rising' => 15, 'stable' => 0, 'falling' => -8, 'unknown' => 5
          }.freeze

          WEIGHTS = { logistics: 0.45, operational: 0.45, weather: 0.1 }.freeze

          class << self
            def descriptor
              @descriptor ||= Infrastructure::ProviderCatalogue.find!('heuristic')
            end
          end

          def assess(subject)
            dimensions = {
              'logistics' => logistics_score(subject),
              'operational' => operational_score(subject),
              'weather' => weather_score(subject)
            }.compact

            return nil if dimensions.empty?

            draft(
              risk_score: weighted_score(dimensions),
              dimensions: dimensions,
              reason: build_reason(subject, dimensions),
              data_sources: ['Internes Heuristikmodell'],
              confidence: CONFIDENCE,
              expires_in: 60.minutes
            )
          end

          private

          def logistics_score(subject)
            base = lead_time_score(subject.lead_time_days) +
                   TRANSPORT_MODE_FACTORS.fetch(subject.transport_mode.to_s, 3) +
                   FREIGHT_TREND_FACTORS.fetch(subject.freight_cost_trend.to_s, 5)

            clamp(base)
          end

          def operational_score(subject)
            base = delay_score(subject) +
                   (subject.is_single_source ? 20 : 0) +
                   rating_score(subject.supplier_rating) +
                   disruption_recency_score(subject.last_disruption_at)

            clamp(base)
          end

          # Weather only gets a value when there is a signal for it; otherwise the
          # dimension stays empty and is excluded from the weighted average.
          def weather_score(subject)
            return nil if subject.last_disruption_at.blank?

            cause = subject.last_disruption_cause.to_s.downcase
            return nil unless WEATHER_KEYWORDS.any? { |word| cause.include?(word) }

            clamp(35 + disruption_recency_score(subject.last_disruption_at))
          end

          def lead_time_score(days)
            value = days.to_i
            entry = LEAD_TIME_SCORES.find { |row| value <= row[:max_days] }
            entry ? entry[:score] : LEAD_TIME_FALLBACK
          end

          def delay_score(subject)
            count = subject.historical_delay_count.to_i
            return 0 if count.zero?

            late_share = count.to_f / (count + 4)
            clamp((late_share * 100).round)
          end

          def rating_score(rating)
            return 10 if rating.nil?

            (5 - rating.to_i).clamp(0, 4) * 8
          end

          def disruption_recency_score(timestamp)
            return 0 if timestamp.blank?

            age = Time.current - timestamp
            return 15 if age <= 90.days
            return 7 if age <= 365.days

            3
          end

          def weighted_score(dimensions)
            applicable = dimensions.slice(*WEIGHTS.keys.map(&:to_s))
            return dimensions.values.first.to_i if applicable.empty?

            weight_sum = applicable.keys.sum { |key| WEIGHTS.fetch(key.to_sym) }
            return 0 if weight_sum.zero?

            total = applicable.sum { |key, value| value * WEIGHTS.fetch(key.to_sym) }
            (total / weight_sum).round
          end

          def clamp(value)
            [[value.round, 0].max, MAX].min
          end

          def build_reason(subject, dimensions)
            parts = ["Lieferzeit #{subject.lead_time_days} Tage"]
            parts << "Transportweg #{subject.transport_mode}" if subject.transport_mode.present?
            parts << "Frachtraten #{subject.freight_cost_trend}" if subject.freight_cost_trend.present?
            parts << 'Einzelquelle' if subject.is_single_source
            if subject.historical_delay_count.to_i.positive?
              parts << "#{subject.historical_delay_count} Verspätungen"
            end
            parts << "Dimensionen: #{dimensions.keys.join(', ')}"
            parts.join(' · ')
          end
        end
      end
    end
  end
end