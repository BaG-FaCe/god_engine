# frozen_string_literal: true

# Migration state and run history - stored in the `logs` database (see
# DatabaseSetup::TableRouting).
#
# Every execution of the legacy→SQL data migration is recorded here so an
# operator can see when it ran, how many tables/rows were imported and whether
# it failed. Duplicate protection *itself* comes from the preserved UUID
# primary keys (see DatabaseSetup::LegacyMigration#insert_missing) - this table
# only makes the migration auditable, it never gates it.
class CreateMigrationRuns < DatabaseSetup::PlatformMigration
  def change
    routed_create_table :migration_runs, id: :string, limit: 36 do |t|
      t.string :run_key, null: false
      t.string :status, null: false, default: 'running'
      t.string :source_adapter
      t.string :target_adapter
      t.string :target_host
      t.integer :tables_imported, null: false, default: 0
      t.integer :rows_imported, null: false, default: 0
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.string :error_class
      t.text :error_message
      t.timestamps
    end
    routed_add_index :migration_runs, :run_key
    routed_add_index :migration_runs, :status
    routed_add_index :migration_runs, :started_at
  end
end
