# Manually maintained supply-chain risk master data for a material.
#
# This record is the *fallback* of the risk module: when no external provider is
# configured or reachable, these hand-maintained fields plus the internal
# heuristic provider still produce a usable traffic light (see
# docs/07-risk-data-providers.md).
class MaterialRiskProfile < ApplicationRecord
  TRANSPORT_MODES = %w[sea air road rail multimodal].freeze
  FREIGHT_COST_TRENDS = %w[rising stable falling unknown].freeze
  MANUAL_LEVELS = %w[green yellow red].freeze

  belongs_to :material, inverse_of: :material_risk_profile
  belongs_to :manually_assessed_by, class_name: 'User', optional: true

  validates :transport_mode, inclusion: { in: TRANSPORT_MODES }, allow_nil: true
  validates :freight_cost_trend, inclusion: { in: FREIGHT_COST_TRENDS }
  validates :manual_risk_level, inclusion: { in: MANUAL_LEVELS }, allow_nil: true
  validates :origin_country, length: { is: 2 }, allow_nil: true
  validates :hs_code, format: { with: /\A\d{4,10}\z/ }, allow_nil: true
  validates :historical_delay_count, :historical_delay_days,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  # Score contribution of a manual traffic light (0-100 scale).
  MANUAL_LEVEL_SCORES = { 'green' => 15, 'yellow' => 50, 'red' => 85 }.freeze

  def manual_score
    MANUAL_LEVEL_SCORES[manual_risk_level]
  end

  def manually_assessed?
    manual_risk_level.present?
  end

  def record_manual_assessment!(level:, note:, user: nil, score: nil)
    update!(
      manual_risk_level: level,
      manual_risk_note: note,
      manual_score_override: score,
      manually_assessed_at: Time.current,
      manually_assessed_by: user
    )
  end

  # Percentage of deliveries that were late, derived from the historical
  # counters. Used by the heuristic provider.
  def historical_delay_ratio
    return nil if historical_delay_count.nil?

    deliveries = material.quantity.to_f
    return nil if deliveries <= 0

    (historical_delay_count / (deliveries + historical_delay_count)).round(4)
  end
end