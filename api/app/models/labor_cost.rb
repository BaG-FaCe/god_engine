# Tab 3 - direct labour per project or batch.
#
# `total_cents` is derived, never stored: it is always `hours * hourly_rate_cents`
# so the record can never become internally inconsistent.
class LaborCost < ApplicationRecord
  belongs_to :project, inverse_of: :labor_costs

  validates :employee, presence: true, length: { maximum: 160 }
  validates :hours, numericality: { greater_than_or_equal_to: 0 }
  validates :hourly_rate_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:position, :employee) }
  scope :by_department, -> { group(:department).sum(:hourly_rate_cents) }

  # `hours * hourly_rate_cents`, rounded half-up to whole cents.
  def total_amount_cents
    (BigDecimal(hours.to_s) * BigDecimal(hourly_rate_cents.to_s)).round(0, half: :up).to_i
  end

  # Alias used by the serialisers and the calculator.
  def total_cents
    total_amount_cents
  end

  def self.total_cents(scope = all)
    scope.sum { |record| record.total_amount_cents }
  end

  def self.total_hours(scope = all)
    scope.sum(:hours)
  end
end