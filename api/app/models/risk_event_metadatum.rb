# One free-form metadata entry of a `RiskEvent` (formerly the
# `risk_events.metadata` JSON hash). Values are stored JSON-encoded so the
# original scalar type (string/number/boolean/array/hash) is recoverable.
class RiskEventMetadatum < EventsRecord
  belongs_to :risk_event, inverse_of: :risk_event_metadata

  validates :key, presence: true, length: { maximum: 255 }

  scope :ordered, -> { order(:position, :key) }

  def parsed_value
    JSON.parse(value) if value.present?
  rescue JSON::ParserError
    value
  end
end
