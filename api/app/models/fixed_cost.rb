# Tab 3 - one-off and fixed project costs (development, tooling, certification).
#
# `allocation_basis` decides how the amount reaches the unit price:
#   per_unit  -> the whole amount is spread over `project.batch_size` units
#   per_batch -> identical to per_unit for a single batch order
#   per_month -> spread over `project.units_per_month` units of one month
class FixedCost < ApplicationRecord
  CATEGORIES = %w[
    labor development engineering quality_control packaging sales depreciation other
  ].freeze

  ALLOCATION_BASES = %w[per_unit per_month per_batch].freeze

  belongs_to :project, inverse_of: :fixed_costs

  validates :name, presence: true, length: { maximum: 200 }
  validates :category, inclusion: { in: CATEGORIES }
  validates :allocation_basis, inclusion: { in: ALLOCATION_BASES }
  validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:position, :created_at) }
  scope :per_unit, -> { where(allocation_basis: %w[per_unit per_batch]) }
  scope :per_month, -> { where(allocation_basis: 'per_month') }

  def per_unit_cents(batch_size:, units_per_month:)
    divisor =
      case allocation_basis
      when 'per_month' then units_per_month.to_i
      else batch_size.to_i
      end
    return 0 if divisor <= 0

    (BigDecimal(amount_cents.to_s) / BigDecimal(divisor.to_s)).round(0, half: :up).to_i
  end
end