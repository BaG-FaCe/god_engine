# Append-only audit trail.
#
# Rows are written by `Shared::Infrastructure::Audit::Recorder` through the
# `Shared::Infrastructure::Audit::Auditable` concern. Nothing in the application
# updates or deletes audit rows, which is what makes the trail trustworthy in an
# audit (ISO 9001 / IATF 16949).
# `audit_logs`, `audit_log_changes` and `audit_log_metadata` live in the `logs`
# database of a SQL backend.
class AuditLog < LogsRecord
  ACTIONS = %w[
    create update delete import export archive restore login refresh configure
    failed_login logout revoke_session revoke_all_sessions password_change
    user_create user_update user_disable user_enable
  ].freeze

  # The JSON column is called `changeset` because Active Record reserves
  # `changes` for dirty tracking (`ActiveRecord::DangerousAttributeError`).
  belongs_to :user, optional: true
  belongs_to :project, optional: true

  has_many :audit_log_changes, -> { order(:position, :attribute_name) },
            dependent: :destroy, inverse_of: :audit_log
  has_many :audit_log_metadata, -> { order(:position, :key) },
            dependent: :destroy, inverse_of: :audit_log

  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :occurred_at, presence: true

  scope :recent, -> { order(occurred_at: :desc) }
  scope :for_project, ->(project_id) { where(project_id: project_id) }
  scope :since, ->(time) { where(occurred_at: time..) }

  # Reconstructs the merged `changeset` (attribute diffs + metadata) for
  # read-back compatibility with the pre-relational JSON column.
  def changeset
    changes = audit_log_changes.each_with_object({}) do |entry, hash|
      hash[entry.attribute_name] = { 'from' => entry.old_value_parsed, 'to' => entry.new_value_parsed }
    end
    audit_log_metadata.each_with_object(changes) do |entry, hash|
      hash[entry.key] = entry.parsed_value
    end
  end

  def readonly?
    persisted?
  end
end