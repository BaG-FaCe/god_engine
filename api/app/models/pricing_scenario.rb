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

  def activate!
    transaction do
      project.pricing_scenarios.where.not(id: id).update_all(is_active: false, updated_at: Time.current)
      update!(is_active: true)
    end
  end

  def self.activate_none!(project)
    project.pricing_scenarios.update_all(is_active: false, updated_at: Time.current)
  end
end