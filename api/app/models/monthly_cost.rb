# Tab 2 - recurring monthly costs (rent, energy, marketing, ...).
#
# Monthly costs are period costs: they are spread over the units produced per
# month, which is why the calculator needs `project.units_per_month`.
class MonthlyCost < ApplicationRecord
  CATEGORIES = %w[
    rent energy marketing insurance hosting leasing maintenance software other
  ].freeze

  belongs_to :project, inverse_of: :monthly_costs

  validates :name, presence: true, length: { maximum: 200 }
  validates :category, inclusion: { in: CATEGORIES }
  validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :currency, length: { is: 3 }

  scope :ordered, -> { order(:position, :created_at) }
  scope :recurring, -> { where(is_recurring: true) }
  scope :one_off, -> { where(is_recurring: false) }

  def self.total_cents
    sum(:amount_cents)
  end

  def self.by_category
    group(:category).sum(:amount_cents)
  end

  # Deviation against the imported benchmark (from a cost template).
  def benchmark_deviation_cents
    return nil if benchmark_amount_cents.nil?

    amount_cents - benchmark_amount_cents
  end

  def benchmark_deviation_pct
    return nil if benchmark_amount_cents.nil? || benchmark_amount_cents.zero?

    benchmark_deviation_cents.to_f / benchmark_amount_cents
  end
end