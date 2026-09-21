module Calculator
  module Domain
    # Turns the aggregated supply chain risk score into the surcharge that is
    # added to the price.
    #
    # This is the single place where risk data influences the sale price - the
    # rest of the calculator only consumes the resulting percentage. Keeping the
    # policy in one class means the "why is this product more expensive" question
    # has exactly one answer, which is also what the UI explains.
    #
    # The model is deliberately simple, linear and capped, so a buyer can follow
    # it:
    #
    #   surcharge = score/100 * MAX_SURCHARGE                     (base)
    #             + CRITICAL_BONUS per critical material          (capped)
    #             + SINGLE_SOURCE_BONUS per single sourced part   (capped)
    #             capped at MAX_SURCHARGE
    #
    # Every limit is configurable through ENV, so a company can calibrate the
    # policy to its own risk appetite without a code change.
    class RiskSurchargePolicy
      DEFAULT_MAX_SURCHARGE = BigDecimal('0.15')
      DEFAULT_CRITICAL_BONUS = BigDecimal('0.015')
      DEFAULT_CRITICAL_BONUS_CAP = BigDecimal('0.05')
      DEFAULT_SINGLE_SOURCE_BONUS = BigDecimal('0.005')
      DEFAULT_SINGLE_SOURCE_BONUS_CAP = BigDecimal('0.03')

      # Score thresholds of the traffic light (0-33 / 34-66 / 67-100).
      MEDIUM_THRESHOLD = 34
      HIGH_THRESHOLD = 67

      Result = Data.define(
        :score, :level, :base_pct, :critical_bonus_pct, :single_source_bonus_pct,
        :suggested_pct, :applied_pct, :reason, :critical_material_count,
        :single_source_count, :material_count, :source
      ) do
        def to_h
          {
            aggregateScore: score,
            level: level,
            suggestedSurchargePct: suggested_pct.to_f.round(6),
            appliedSurchargePct: applied_pct.to_f.round(6),
            criticalMaterialCount: critical_material_count,
            singleSourceCount: single_source_count,
            materialCount: material_count,
            reason: reason,
            source: source
          }
        end
      end

      class << self
        # @param aggregate_score [Numeric, nil] 0-100, nil when no risk data exists
        # @param manual_override [Numeric, nil] decimal fraction from the project
        def call(aggregate_score:, material_count: 0, critical_material_count: 0,
                 single_source_count: 0, manual_override: nil)
          # A manual override always wins - a human decision must never be
          # silently overwritten by a heuristic.
          if manual_override.present?
            return Result.new(
              score: aggregate_score, level: level_for(aggregate_score),
              base_pct: BigDecimal(0), critical_bonus_pct: BigDecimal(0),
              single_source_bonus_pct: BigDecimal(0), suggested_pct: BigDecimal(0),
              applied_pct: decimal(manual_override),
              reason: 'Manuell gepflegter Risikozuschlag',
              critical_material_count: critical_material_count,
              single_source_count: single_source_count,
              material_count: material_count, source: 'manual'
            )
          end

          if aggregate_score.nil?
            return Result.new(
              score: nil, level: nil, base_pct: BigDecimal(0),
              critical_bonus_pct: BigDecimal(0), single_source_bonus_pct: BigDecimal(0),
              suggested_pct: BigDecimal(0), applied_pct: BigDecimal(0),
              reason: 'Keine Risikodaten vorhanden - kein Zuschlag berechnet',
              critical_material_count: critical_material_count,
              single_source_count: single_source_count,
              material_count: material_count, source: 'none'
            )
          end

          score = decimal(aggregate_score).clamp(BigDecimal(0), BigDecimal(100))
          base = score / 100 * max_surcharge

          critical_bonus =
            [decimal(critical_material_count) * critical_bonus_rate, critical_bonus_cap].min
          single_bonus =
            [decimal(single_source_count) * single_source_bonus_rate,
             single_source_bonus_cap].min

          suggested = [base + critical_bonus + single_bonus, max_surcharge].min.round(6)

          Result.new(
            score: score.to_i,
            level: level_for(score),
            base_pct: base.round(6),
            critical_bonus_pct: critical_bonus.round(6),
            single_source_bonus_pct: single_bonus.round(6),
            suggested_pct: suggested,
            applied_pct: suggested,
            reason: build_reason(score, critical_material_count, single_source_count),
            critical_material_count: critical_material_count,
            single_source_count: single_source_count,
            material_count: material_count,
            source: 'automatic'
          )
        end

        # `0-33` low, `34-66` medium, `67-100` high.
        def level_for(score)
          return nil if score.nil?
          return 'low' if score < MEDIUM_THRESHOLD
          return 'medium' if score < HIGH_THRESHOLD

          'high'
        end

        # True when the applied surcharge materially changes the price - the UI
        # uses this to decide whether to show the warning banner.
        def significant?(applied_pct, threshold = BigDecimal('0.03'))
          decimal(applied_pct) >= threshold
        end

        def max_surcharge
          decimal(ENV.fetch('RISK_SURCHARGE_MAX_PCT', DEFAULT_MAX_SURCHARGE.to_s('F')))
        end

        def critical_bonus_rate
          decimal(ENV.fetch('RISK_SURCHARGE_CRITICAL_BONUS_PCT', DEFAULT_CRITICAL_BONUS.to_s('F')))
        end

        def critical_bonus_cap
          decimal(ENV.fetch('RISK_SURCHARGE_CRITICAL_CAP_PCT', DEFAULT_CRITICAL_BONUS_CAP.to_s('F')))
        end

        def single_source_bonus_rate
          decimal(
            ENV.fetch('RISK_SURCHARGE_SINGLE_SOURCE_BONUS_PCT',
                      DEFAULT_SINGLE_SOURCE_BONUS.to_s('F'))
          )
        end

        def single_source_bonus_cap
          decimal(
            ENV.fetch('RISK_SURCHARGE_SINGLE_SOURCE_CAP_PCT',
                      DEFAULT_SINGLE_SOURCE_BONUS_CAP.to_s('F'))
          )
        end

        private

        def build_reason(score, critical_count, single_source_count)
          parts = ["Aggregierter Lieferrisiko-Score #{score.round} von 100"]
          parts << "#{critical_count} kritische Position(en)" if critical_count.positive?
          parts << "#{single_source_count} Einzelquellen" if single_source_count.positive?
          parts.join(' · ')
        end

        def decimal(value)
          return BigDecimal(0) if value.nil?
          return value if value.is_a?(BigDecimal)

          BigDecimal(value.to_s)
        end
      end
    end
  end
end