# One warning string of a `PricingScenarioResult` (formerly part of the
# `pricing_scenarios.result_snapshot` JSON document's `warnings` array).
class PricingScenarioWarning < ApplicationRecord
  belongs_to :pricing_scenario_result, inverse_of: :warnings

  validates :message, presence: true
end
