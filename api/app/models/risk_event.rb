# An early-warning signal for a material, a project or a country.
#
# Events come from three places:
#   1. open data providers (GDACS, USGS, Open-Meteo, port congestion feeds)
#   2. paid SCRM platforms, when a key is configured
#   3. users, who can log a disruption manually
#
# The `(source, source_event_id)` unique index makes ingestion idempotent, which
# matters because the open data feeds are polled repeatedly and often overlap.
class RiskEvent < EventsRecord
  TYPES = %w[weather disaster sanction port_congestion price_spike customs supplier manual].freeze
  SEVERITIES = %w[low medium high critical].freeze

  # How much each severity contributes to a material's risk score.
  SEVERITY_WEIGHTS = {
    'low' => 4, 'medium' => 12, 'high' => 22, 'critical' => 35
  }.freeze

  belongs_to :material, optional: true, inverse_of: :risk_events
  belongs_to :project, optional: true
  belongs_to :acknowledged_by, class_name: 'User', optional: true

  has_many :risk_event_metadata, -> { order(:position, :key) },
            dependent: :destroy, inverse_of: :risk_event

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

  # Reconstructs the free-form metadata hash (formerly a JSON column).
  def metadata
    risk_event_metadata.each_with_object({}) { |entry, hash| hash[entry.key] = entry.parsed_value }
  end

  # Replaces the metadata entries from a free-form hash (values JSON-encoded).
  def replace_metadata!(hash)
    return if hash.blank?

    transaction do
      risk_event_metadata.destroy_all
      hash.each_with_index do |(key, value), index|
        risk_event_metadata.create!(key: key.to_s, value: value.to_json, position: index)
      end
    end
  end

  def acknowledge!(user)
    update!(acknowledged_at: Time.current, acknowledged_by: user)
  end

  def acknowledged?
    acknowledged_at.present?
  end
end