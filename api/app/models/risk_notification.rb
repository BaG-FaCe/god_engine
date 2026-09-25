# In-app risk notifications (spec § Lieferrisiko: "Bei 🔴 oder neuem risk_event wird eine In-App-Benachrichtigung ausgelöst").
#
# Lifecycle:
#   * created by `NotifyRiskAlert` (never deleted)
#   * acknowledged by the current user (marker "gesehen", bleibt in Historie)
#   * dismissed by the current user (verworfen, aber nicht gelöscht, damit Audit-Historie erhalten bleibt)
class RiskNotification < ApplicationRecord
  KINDS = %w[risk_event critical_material].freeze
  SEVERITIES = %w[low medium high critical].freeze

  belongs_to :project, optional: true
  belongs_to :material, optional: true
  belongs_to :risk_event, optional: true
  belongs_to :read_by, class_name: 'User', optional: true
  belongs_to :acknowledged_by, class_name: 'User', optional: true
  belongs_to :dismissed_by, class_name: 'User', optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :severity, inclusion: { in: SEVERITIES }
  validates :title, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :undismissed, -> { where(dismissed_at: nil) }
  scope :open, -> { undismissed }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_project, ->(project) { where(project_id: [nil, project&.id]) }
  scope :for_material, ->(material) { where(material_id: material&.id) }

  # Lifecycle status exposed by the API - see RiskNotificationsController.
  def status
    return 'dismissed' if dismissed?
    return 'acknowledged' if acknowledged?
    return 'read' if read?

    'unread'
  end

  def read?
    read_at.present?
  end

  def acknowledged?
    acknowledged_at.present?
  end

  def dismissed?
    dismissed_at.present?
  end

  def mark_read!(user: nil)
    update!(read_at: Time.current, read_by: user) unless read?
  end

  def acknowledge!(user)
    return if acknowledged?
    update!(acknowledged_at: Time.current, acknowledged_by: user)
  end

  def dismiss!(user)
    return if dismissed?
    update!(dismissed_at: Time.current, dismissed_by: user)
  end
end
