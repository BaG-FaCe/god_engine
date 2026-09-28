# One metadata entry of an `AuditLog` (formerly part of the
# `audit_logs.changeset` JSON hash, e.g. `format`, `providerKey`, `source`).
class AuditLogMetadatum < LogsRecord
  belongs_to :audit_log, inverse_of: :audit_log_metadata

  validates :key, presence: true, length: { maximum: 255 }

  scope :ordered, -> { order(:position, :key) }

  def parsed_value
    return nil if value.blank?

    JSON.parse(value)
  rescue JSON::ParserError
    value
  end
end
