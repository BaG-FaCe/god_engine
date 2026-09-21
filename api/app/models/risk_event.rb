# An early-warning signal for a material, a project or a country.
#
# Events come from three places:
#   1. open data providers (GDACS, USGS, Open-Meteo, port congestion feeds)
#   2. paid SCRM platforms, when a key is configured
#   3. users, who can log a disruption manually
#
# The `(source, source_event_id)` unique index makes ingestion idempotent, which
# matters because the open data feeds are polled repeatedly and often overlap.
class RiskEvent < ApplicationRecord
  TYPES = %w[weather disaster sanction port_congestion price_spike customs supplier manual].freeze
  SEVERITIES = %w[low medium high critical].freeze

  # How much each severity contributes to a material's risk score.
  SEVERITY_WEIGHTS = {
    'low' => 4, 'medium' => 12, 'high' => 22, 'critical' => 35
  }.freeze

  belongs_to :material, optional: true, inverse_of: :risk_events
  belongs_to :project, optional: true
  belongs_to :acknowledged_by, class_name: 'User', optional: true

  validates :title, presence: true, length: { maximum: 300 }
  validates :event_type, inclusion: { in: TYPES }
  validates :severity, inclusion: { in: SEVERITIES }
  validates :source, presence: true
  validates :occurred_at, presence: true
  validates :source_event_id, uniqueness: { scope: :source }, allow_nil: true

  scope :recent, -> { order(occurred_at: :desc) }
  scope :critical, -> { where(severity: %w[high critical]) }
  scope :unacknowledged, -> { where(acknowledged_at: nil) }
  scope :for_country, ->(code) { where(country_code: code.to_s.upcase) }
  scope :since, ->(time) { where(occurred_at: time..) }

  def severity_weight
    SEVERITY_WEIGHTS.fetch(severity, 5)
  end

  def acknowledge!(user)
    update!(acknowledged_at: Time.current, acknowledged_by: user)
  end

  def acknowledged?
    acknowledged_at.present?
  end
end