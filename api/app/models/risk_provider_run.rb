# Bookkeeping for a single execution of a risk provider adapter.
#
# This is the operational counterpart to the open-data quota documentation: it
# makes it observable *when* which provider ran, how long it took and how many
# calls it consumed (deliverable 11 - "Externe API-Anbindung" / Monitoring).
class RiskProviderRun < ApplicationRecord
  STATUSES = %w[ok partial error skipped].freeze

  validates :provider_key, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :started_at, presence: true

  scope :recent, -> { order(started_at: :desc) }
  scope :successful, -> { where(status: %w[ok partial]) }
  scope :failed, -> { where(status: 'error') }
  scope :since, ->(time) { where(started_at: time..) }

  def self.track(provider_key, project_id: nil)
    run = create!(provider_key: provider_key, project_id: project_id,
                 status: 'ok', started_at: Time.current)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    result = yield(run)

    run.update!(
      status: 'ok',
      finished_at: Time.current,
      duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
    )
    result
  rescue StandardError => e
    run.update!(
      status: 'error',
      finished_at: Time.current,
      error_class: e.class.name,
      error_message: e.message.to_s.truncate(2000),
      duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
    )
    raise
  end

  # Number of outbound calls consumed within the rolling window - used by the
  # monitoring endpoint to warn before a free tier quota is exhausted.
  def self.requests_in_window(window = 24.hours)
    since(window.ago).sum(:requests_made)
  end
end