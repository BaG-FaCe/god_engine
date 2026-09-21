# A purchased part with all Tab-1 (Materialkalkulation) data plus the
# denormalised risk aggregate.
#
# The risk aggregate columns (`risk_score`, `risk_level`, `last_risk_checked_at`)
# are written exclusively by
# `SupplyChainRisk::Application::AggregateProductRisk`. The `calculator` context
# reads only these columns - it never queries the risk tables itself, which is
# what keeps the two contexts decoupled.
class Material < ApplicationRecord
  MATERIAL_TYPES = %w[
    raw_material component fastener electronics packaging consumable service other
  ].freeze

  LEAD_TIME_UNITS = %w[days weeks months].freeze

  # Normalisation factors so every lead time can be compared in days.
  LEAD_TIME_UNIT_IN_DAYS = { 'days' => 1, 'weeks' => 7, 'months' => 30 }.freeze

  UNITS = %w[Stk kg g l m m2 m3 h Set Paar Rolle].freeze

  belongs_to :project
  belongs_to :supplier, optional: true
  has_one :material_risk_profile, dependent: :destroy
  has_many :alternative_suppliers, -> { order(:priority) }, dependent: :destroy
  has_many :material_documents, dependent: :destroy
  has_many :risk_assessments, dependent: :destroy
  has_many :risk_events, dependent: :destroy
  has_many :risk_score_snapshots, dependent: :destroy

  validates :name, presence: true, length: { maximum: 200 }
  validates :material_type, inclusion: { in: MATERIAL_TYPES }
  validates :unit, presence: true
  validates :lead_time_unit, inclusion: { in: LEAD_TIME_UNITS }
  validates :currency, length: { is: 3 }
  validates :unit_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :quantity, :min_order_quantity, :stock_quantity, :reorder_level,
            numericality: { greater_than_or_equal_to: 0 }
  validates :lead_time_value, :lead_time_days, numericality: { greater_than_or_equal_to: 0 }

  before_validation :normalise_lead_time

  scope :ordered, -> { order(:position, :created_at) }
  scope :search, lambda { |term|
    next all if term.blank?

    pattern = "%#{sanitize_sql_like(term.to_s.strip)}%"
    where('name LIKE :p OR article_number LIKE :p OR description LIKE :p', p: pattern)
  }
  scope :critical_risk, -> { where(risk_level: 'high') }
  scope :elevated_or_critical_risk, -> { where(risk_level: %w[medium high]) }
  scope :without_risk_data, -> { where(risk_score: nil) }
  scope :long_lead, ->(days) { where(lead_time_days: days..) }

  def lead_time_in_days
    lead_time_days
  end

  def lead_time_days_display
    (lead_time_value * LEAD_TIME_UNIT_IN_DAYS.fetch(lead_time_unit, 1)).round(2)
  end

  # Net unit price in cents, regardless of how the price was entered.
  def net_unit_price_cents
    return unit_price_cents unless price_includes_tax?

    tax_rate = project&.tax_rate_fraction || BigDecimal('0')
    denominator = BigDecimal(1) + tax_rate
    return unit_price_cents if denominator.zero?

    (BigDecimal(unit_price_cents.to_s) / denominator).round(0, half: :up).to_i
  end

  def gross_unit_price_cents
    return unit_price_cents if price_includes_tax?

    tax_rate = project&.tax_rate_fraction || BigDecimal('0')
    (BigDecimal(unit_price_cents.to_s) * (BigDecimal(1) + tax_rate)).round(0, half: :up).to_i
  end

  def total_value_net_cents
    (BigDecimal(net_unit_price_cents.to_s) * BigDecimal(quantity.to_s)).round(0, half: :up).to_i
  end

  # Extended cost of one batch, i.e. the quantity that is actually purchased.
  def procurement_quantity
    [BigDecimal(quantity.to_s), BigDecimal(min_order_quantity.to_s)].max
  end

  def below_reorder_level?
    BigDecimal(stock_quantity.to_s) < BigDecimal(reorder_level.to_s)
  end

  def latest_risk_assessment
    risk_assessments.order(fetched_at: :desc).first
  end

  def risk_profile
    material_risk_profile || build_material_risk_profile
  end

  private

  def normalise_lead_time
    return if lead_time_value.nil?

    self.lead_time_days =
      (BigDecimal(lead_time_value.to_s) *
       BigDecimal(LEAD_TIME_UNIT_IN_DAYS.fetch(lead_time_unit, 1).to_s)).round.to_i
  end
end