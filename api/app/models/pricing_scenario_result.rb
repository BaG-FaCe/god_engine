# The 1:1 persisted result snapshot of a `PricingScenario` (formerly the
# `pricing_scenarios.result_snapshot` JSON document). It stores the scalar
# values of a `Calculator::Domain::PriceOptimizer::Result`; the only array
# (`warnings`) lives in `PricingScenarioWarning`.
class PricingScenarioResult < ApplicationRecord
  belongs_to :pricing_scenario, inverse_of: :result
  has_many :warnings, -> { order(:position) },
            class_name: 'PricingScenarioWarning',
            dependent: :destroy, inverse_of: :pricing_scenario_result

  # Reconstructs the exact `PriceOptimizer::Result#to_h` structure consumed by
  # the REST contract (`resultSnapshot`).
  def to_h
    {
      target: {
        priceCents: target_price_cents, includesTax: target_includes_tax,
        netCents: target_net_cents, grossCents: target_gross_cents
      },
      calculated: { netCents: calculated_net_cents, grossCents: calculated_gross_cents },
      profit: {
        perUnitNetCents: profit_per_unit_net_cents,
        perUnitGrossCents: profit_per_unit_gross_cents,
        marginPct: decimal(profit_margin_pct),
        markupPct: decimal(profit_markup_pct),
        contributionMarginPerUnitCents: profit_contribution_margin_per_unit_cents,
        contributionMarginRatioPct: decimal(profit_contribution_margin_ratio_pct),
        variableCostPerUnitCents: profit_variable_cost_per_unit_cents,
        fullCostPerUnitCents: profit_full_cost_per_unit_cents
      },
      revenue: {
        monthlyNetCents: revenue_monthly_net_cents,
        monthlyGrossCents: revenue_monthly_gross_cents,
        batchNetCents: revenue_batch_net_cents,
        batchGrossCents: revenue_batch_gross_cents
      },
      monthlyProfit: {
        netCents: monthly_profit_net_cents,
        marginPct: decimal(monthly_profit_margin_pct),
        unitsPerMonth: monthly_profit_units_per_month
      },
      breakEven: {
        unitsPerMonth: break_even_units_per_month,
        revenueNetCents: break_even_revenue_net_cents,
        feasible: break_even_feasible,
        reason: break_even_reason,
        coverageRatioPct: decimal(break_even_coverage_ratio_pct),
        currentVolume: break_even_current_volume
      },
      variableCost: {
        perUnitCents: variable_cost_per_unit_cents,
        shareOfPricePct: decimal(variable_cost_share_of_price_pct)
      },
      fixedCost: {
        perMonthCents: fixed_cost_per_month_cents,
        perUnitAtVolumeCents: fixed_cost_per_unit_at_volume_cents
      },
      warnings: warnings.map(&:message)
    }
  end

  private

  def decimal(value)
    value.nil? ? nil : value.to_f
  end
end
