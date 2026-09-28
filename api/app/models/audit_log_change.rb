# One attribute diff of an `AuditLog` (formerly part of the
# `audit_logs.changeset` JSON hash). Values are stored JSON-encoded so the
# original scalar/array/hash type is recoverable.
class AuditLogChange < LogsRecord
  belongs_to :audit_log, inverse_of: :audit_log_changes

  validates :attribute_name, presence: true, length: { maximum: 255 }

  scope :ordered, -> { order(:position, :attribute_name) }

  def old_value_parsed
    parse_value(old_value)
  end

  def new_value_parsed
    parse_value(new_value)
  end

  private

  def parse_value(value)
    return nil if value.blank?

    JSON.parse(value)
  rescue JSON::ParserError
    value
  end
end
