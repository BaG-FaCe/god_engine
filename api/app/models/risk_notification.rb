# In-app risk notification (spec § Lieferrisiko-Management).
#
# Created by `SupplyChainRisk::Application::NotifyRiskAlert` when
#   * a material's aggregated traffic light flips to 🔴 (high), or
#   * a new risk event (disaster, sanction, ...) arrives for a project,
# and displayed by the dashboard / read through
# `GET /api/v1/risk_notifications`.
class RiskNotification < ApplicationRecord
  KINDS = %w[risk_event critical_material].freeze
  SEVERITIES = %w[low medium high critical].freeze

  belongs_to :project, optional: true
  belongs_to :material, optional: true
  belongs_to :risk_event, optional: true
  belongs_to :read_by, class_name: 'User', optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :severity, inclusion: { in: SEVERITIES }
  validates :title, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_project, ->(project) { where(project_id: [nil, project&.id]) }

  def read?
    read_at.present?
  end

  def mark_read!(user: nil)
    update!(read_at: Time.current, read_by: user) unless read?
  end
end
