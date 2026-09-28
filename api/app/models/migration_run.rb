# State of a legacy→SQL data migration run (stored in the `logs` database).
#
# Every bootstrap/migration execution writes exactly one row: `running` while it
# is in flight, then `ok` or `error`. This is what makes the migration auditable
# ("was the migration already run, when, how many rows, did it fail?"), while
# duplicate protection itself is guaranteed by the UUID primary keys the import
# preserves (see DatabaseSetup::LegacyMigration).
class MigrationRun < LogsRecord
  STATUSES = %w[running ok error].freeze

  validates :run_key, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :started_at, presence: true

  scope :recent, -> { order(started_at: :desc) }
  scope :successful, -> { where(status: 'ok') }
  scope :failed, -> { where(status: 'error') }

  def self.start!(run_key:, source_adapter: nil, target_adapter: nil, target_host: nil)
    create!(
      run_key: run_key,
      status: 'running',
      source_adapter: source_adapter,
      target_adapter: target_adapter,
      target_host: target_host,
      started_at: Time.current
    )
  end

  def finish!(tables_imported: 0, rows_imported: 0)
    update!(
      status: 'ok',
      tables_imported: tables_imported,
      rows_imported: rows_imported,
      finished_at: Time.current
    )
  end

  def fail!(error)
    update!(
      status: 'error',
      finished_at: Time.current,
      error_class: error.class.name,
      error_message: error.message.to_s.truncate(2000)
    )
  end

  def finished?
    status != 'running'
  end
end
