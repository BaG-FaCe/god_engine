# frozen_string_literal: true

module DatabaseSetup
  # Orchestrates the one-time SQL backend bootstrap:
  #
  #   1. snapshot the legacy (SQLite) data into memory,
  #   2. provision the four databases on the server,
  #   3. create the schema (run the app's migrations, routed per database),
  #   4. migrate the legacy data into the new schema,
  #   5. record the migration run in the `logs` database,
  #   6. seed the initial entry (admin user + demo project),
  #   7. verify the result.
  #
  # The legacy source is only ever *read*: it stays untouched, which keeps the
  # migration reversible from a data-recovery perspective. Steps 1-2 never touch
  # the active connection, step 3 switches the connections to the SQL backend,
  # steps 4-7 write through them.
  class Bootstrap
    def self.call(configuration, logger: Rails.logger)
      new(configuration, logger: logger).call
    end

    def initialize(configuration, logger: Rails.logger)
      @configuration = configuration
      @logger = logger
    end

    def call
      snapshot = LegacyMigration.extract
      provisioned = Provisioner.call(@configuration)
      schema = SchemaLoader.call(@configuration)

      run = MigrationRun.start!(
        run_key: 'legacy_json_sqlite_to_sql',
        source_adapter: 'sqlite',
        target_adapter: @configuration.adapter,
        target_host: @configuration.host
      )

      begin
        imported = LegacyMigration.import(snapshot)
        seeded = Seeder.call
        verification = Verification.call(@configuration)
        unless verification[:ok]
          raise Verification::Error, Verification.failure_message(verification)
        end

        run.finish!(tables_imported: imported.size, rows_imported: imported.values.sum)
      rescue StandardError => e
        run.fail!(e) unless run.finished?
        raise
      end

      {
        provisioned: provisioned,
        schema: schema,
        imported: imported,
        seeded: seeded,
        verification: verification,
        migration_run: run.id,
        adapter: @configuration.adapter
      }
    end
  end
end

