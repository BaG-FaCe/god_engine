# Append-only audit trail.
#
# Rows are written by `Shared::Infrastructure::Audit::Recorder` through the
# `Shared::Infrastructure::Audit::Auditable` concern. Nothing in the application
# updates or deletes audit rows, which is what makes the trail trustworthy in an
# audit (ISO 9001 / IATF 16949).
class AuditLog < ApplicationRecord
  ACTIONS = %w[create update delete import export archive restore login refresh configure].freeze

  # The JSON column is called `changeset` because Active Record reserves
  # `changes` for dirty tracking (`ActiveRecord::DangerousAttributeError`).
  belongs_to :user, optional: true
  belongs_to :project, optional: true

  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :occurred_at, presence: true

  scope :recent, -> { order(occurred_at: :desc) }
  scope :for_project, ->(project_id) { where(project_id: project_id) }
  scope :since, ->(time) { where(occurred_at: time..) }

  def readonly?
    persisted?
  end
end