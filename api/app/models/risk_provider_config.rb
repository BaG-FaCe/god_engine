# Per-project configuration of a risk data provider.
#
# The API key is stored with `ActiveRecord::Encryption`, so it is encrypted at
# rest in SQLite and never returned by any endpoint - the serializer only exposes
# `apiKeyPresent` and a masked hint.
class RiskProviderConfig < ApplicationRecord
  STATUSES = %w[ok error never_run].freeze

  encrypts :api_key

  belongs_to :project, optional: true

  validates :provider_key, presence: true
  validates :poll_interval_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 5 }
  validates :priority, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :last_run_status, inclusion: { in: STATUSES }, allow_nil: true

  scope :enabled, -> { where(enabled: true) }
  scope :ordered, -> { order(:priority, :provider_key) }
  scope :for_project, ->(project) { where(project_id: [nil, project&.id]) }

  def api_key_present?
    api_key.present?
  end

  # Never leak the secret - only a recognisable tail.
  def api_key_hint
    return nil unless api_key_present?
    return '••••' if api_key.length <= 4

    "#{'•' * 4}#{api_key[-4..]}"
  end

  def mark_success!(at: Time.current)
    update_columns(last_run_at: at, last_run_status: 'ok', last_error: nil,
                   consecutive_failures: 0, updated_at: at)
  end

  def mark_failure!(error)
    update_columns(
      last_run_at: Time.current,
      last_run_status: 'error',
      last_error: error.to_s.truncate(2000),
      consecutive_failures: consecutive_failures + 1,
      updated_at: Time.current
    )
  end

  def due_for_poll?
    return true if last_run_at.nil?

    last_run_at + poll_interval_minutes.minutes <= Time.current
  end
end