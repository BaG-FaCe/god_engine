# A calculation project: the root aggregate of the `calculator` context.
#
# Everything the four calculation tabs need hangs off this record. Risk data is
# deliberately *not* owned here - the project only stores the configured risk
# surcharge behaviour and reads aggregate risk through the risk module.
class Project < ApplicationRecord
  STATUSES = %w[draft active archived].freeze

  belongs_to :owner, class_name: 'User', optional: true, inverse_of: :owned_projects

  has_many :suppliers, dependent: :destroy
  has_many :materials, -> { order(:position, :created_at) }, dependent: :destroy,
                       inverse_of: :project
  has_many :monthly_costs, -> { order(:position, :created_at) }, dependent: :destroy
  has_many :labor_costs, -> { order(:position, :created_at) }, dependent: :destroy
  has_many :fixed_costs, -> { order(:position, :created_at) }, dependent: :destroy
  has_many :overhead_rules, -> { order(:position, :key) }, dependent: :destroy
  has_many :sales_forecasts, -> { order(:period) }, dependent: :destroy
  has_many :pricing_scenarios, dependent: :destroy
  has_many :cost_templates, dependent: :nullify
  has_many :risk_events, dependent: :destroy
  has_many :risk_provider_configs, dependent: :destroy

  validates :name, presence: true, length: { maximum: 200 }
  validates :status, inclusion: { in: STATUSES }
  validates :country, presence: true, length: { is: 2 }
  validates :currency, presence: true, length: { is: 3 }
  validates :tax_rate, :target_margin_pct, :risk_surcharge_pct,
            numericality: { greater_than_or_equal_to: 0, less_than: 1 }, allow_nil: true
  validates :units_per_month, numericality: { only_integer: true, greater_than: 0 }
  validates :batch_size, numericality: { only_integer: true, greater_than: 0 }
  validates :risk_refresh_interval_hours, numericality: { only_integer: true, greater_than: 0 }

  scope :active, -> { where(status: 'active') }
  scope :ordered, -> { order(updated_at: :desc) }
  scope :search, lambda { |term|
    next all if term.blank?

    pattern = "%#{sanitize_sql_like(term.to_s.strip)}%"
    where('name LIKE :p OR description LIKE :p', p: pattern)
  }

  def archive!
    update!(status: 'archived', archived_at: Time.current)
  end

  def restore!
    update!(status: 'active', archived_at: nil)
  end

  def archived?
    status == 'archived'
  end

  # Monthly volume used by every per-unit calculation.
  def effective_units_per_month
    units_per_month.positive? ? units_per_month : 1
  end

  # The batch size used to spread one-off (upfront) costs.
  def effective_batch_size
    batch_size.positive? ? batch_size : 1
  end

  def tax_rate_fraction
    (tax_rate || BigDecimal('0')).to_d
  end
end