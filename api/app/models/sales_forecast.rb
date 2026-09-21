# Tab 2 - planned versus actual sales volume per month.
#
# The deviation feeds both the dashboard (forecast vs. actual) and the profit
# deviation calculation in `Calculator::Application::AnalyseSalesForecast`.
class SalesForecast < ApplicationRecord
  PERIOD_FORMAT = /\A\d{4}-(0[1-9]|1[0-2])\z/

  belongs_to :project, inverse_of: :sales_forecasts

  validates :period, presence: true, format: { with: PERIOD_FORMAT }
  validates :forecast_units, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :actual_units, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                            allow_nil: true
  validates :period, uniqueness: { scope: :project_id }

  scope :ordered, -> { order(:period) }
  scope :with_actuals, -> { where.not(actual_units: nil) }
  scope :for_range, ->(from, to) { where(period: from..to) }

  def deviation_units
    return nil if actual_units.nil?

    actual_units - forecast_units
  end

  def deviation_pct
    deviation = deviation_units
    return nil if deviation.nil? || forecast_units.zero?

    deviation.to_f / forecast_units
  end

  def year
    period.to_s[0, 4].to_i
  end

  def month
    period.to_s[5, 2].to_i
  end

  # First day of the forecast month - used for trend charts.
  def starts_on
    Date.new(year, month, 1)
  end
end