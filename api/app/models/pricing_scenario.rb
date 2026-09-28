# Tab 4 - a named pricing scenario (what-if target price) for a project.
#
# `result_snapshot` stores the full calculation result at the time the scenario
# was saved, so a historical comparison never changes when master data changes.
class PricingScenario < ApplicationRecord
  belongs_to :project, inverse_of: :pricing_scenarios

  validates :name, presence: true, length: { maximum: 120 },
                   uniqueness: { scope: :project_id, case_sensitive: false }
  validates :target_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                                 allow_nil: true
  validates :units_per_month, :batch_size,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(is_active: :desc, updated_at: :desc) }
  scope :active, -> { where(is_active: true) }

  has_one :result, class_name: 'PricingScenarioResult', dependent: :destroy,
                   inverse_of: :pricing_scenario

  # Persists a `PriceOptimizer::Result` hash as the 1:1 result + warnings.
  # Replaces the previous `result_snapshot` JSON column.
  def store_result!(hash)
    hash = hash.deep_symbolize_keys
    transaction do
      record = result || build_result
      record.assign_attributes(result_attributes(hash))
      record.save!
      record.warnings.destroy_all
      Array(hash[:warnings]).each_with_index do |message, index|
        record.warnings.create!(position: index, message: message.to_s)
      end
    end
    result_snapshot
  end

  # Reconstructs the exact `PriceOptimizer::Result#to_h` structure for the API.
  def result_snapshot
    result&.to_h
  end

  def activate!
    transaction do
      project.pricing_scenarios.where.not(id: id).update_all(is_active: false, updated_at: Time.current)
      update!(is_active: true)
    end
  end

  def self.activate_none!(project)
    project.pricing_scenarios.update_all(is_active: false, updated_at: Time.current)
  end

  private

  def result_attributes(hash)
    {
      target_price_cents: hash.dig(:target, :priceCents),
      target_includes_tax: hash.dig(:target, :includesTax),
      target_net_cents: hash.dig(:target, :netCents),
      target_gross_cents: hash.dig(:target, :grossCents),
      calculated_net_cents: hash.dig(:calculated, :netCents),
      calculated_gross_cents: hash.dig(:calculated, :grossCents),
      profit_per_unit_net_cents: hash.dig(:profit, :perUnitNetCents),
      profit_per_unit_gross_cents: hash.dig(:profit, :perUnitGrossCents),
      profit_margin_pct: hash.dig(:profit, :marginPct),
      profit_markup_pct: hash.dig(:profit, :markupPct),
      profit_contribution_margin_per_unit_cents: hash.dig(:profit, :contributionMarginPerUnitCents),
      profit_contribution_margin_ratio_pct: hash.dig(:profit, :contributionMarginRatioPct),
      profit_variable_cost_per_unit_cents: hash.dig(:profit, :variableCostPerUnitCents),
      profit_full_cost_per_unit_cents: hash.dig(:profit, :fullCostPerUnitCents),
      revenue_monthly_net_cents: hash.dig(:revenue, :monthlyNetCents),
      revenue_monthly_gross_cents: hash.dig(:revenue, :monthlyGrossCents),
      revenue_batch_net_cents: hash.dig(:revenue, :batchNetCents),
      revenue_batch_gross_cents: hash.dig(:revenue, :batchGrossCents),
      monthly_profit_net_cents: hash.dig(:monthlyProfit, :netCents),
      monthly_profit_margin_pct: hash.dig(:monthlyProfit, :marginPct),
      monthly_profit_units_per_month: hash.dig(:monthlyProfit, :unitsPerMonth),
      break_even_units_per_month: hash.dig(:breakEven, :unitsPerMonth),
      break_even_revenue_net_cents: hash.dig(:breakEven, :revenueNetCents),
      break_even_feasible: hash.dig(:breakEven, :feasible),
      break_even_reason: hash.dig(:breakEven, :reason),
      break_even_coverage_ratio_pct: hash.dig(:breakEven, :coverageRatioPct),
      break_even_current_volume: hash.dig(:breakEven, :currentVolume),
      variable_cost_per_unit_cents: hash.dig(:variableCost, :perUnitCents),
      variable_cost_share_of_price_pct: hash.dig(:variableCost, :shareOfPricePct),
      fixed_cost_per_month_cents: hash.dig(:fixedCost, :perMonthCents),
      fixed_cost_per_unit_at_volume_cents: hash.dig(:fixedCost, :perUnitAtVolumeCents)
    }
  end
end