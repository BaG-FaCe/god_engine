# frozen_string_literal: true

# SQL backend bootstrap tasks (operator/CLI equivalents of the first-run setup
# screen). Configuration is resolved from environment variables first, then the
# gitignored local file written by the setup screen.
#
# The application uses four logical databases:
#   productdata (primary) | users | events | logs
namespace :sqlserver do
  def sqlserver_config
    config = DatabaseSetup::ConfigurationStore.load
    abort 'No SQL backend configuration found (set SQL_SERVER/SQL_USER/SQL_PASSWORD or run the first-run setup).' unless config
    unless config.valid?
      abort 'SQL backend configuration is incomplete (adapter, host, username and password are required).'
    end
    config
  end

  desc 'Show SQL backend configuration status (redacted)'
  task status: :environment do
    config = DatabaseSetup::ConfigurationStore.load
    if config
      puts config.redacted.inspect
    else
      puts 'Not configured.'
    end
  end

  desc 'Test connectivity and authentication to the SQL backend (read-only)'
  task test: :environment do
    config = sqlserver_config
    result = DatabaseSetup::Connection.test!(config)
    puts "OK  #{result[:adapter]} #{result[:host]} (#{result[:serverVersion]})"
    existing = DatabaseSetup::Connection.databases(config)
    required = config.database_names
    puts "Existing required databases: #{(existing & required).join(', ')}"
    puts "Missing databases:          #{(required - existing).join(', ')}"
  rescue DatabaseSetup::Connection::Error, DatabaseSetup::Client::Error => e
    abort "Connection failed: #{e.message}"
  end

  desc 'Provision the required databases (create missing ones only)'
  task provision: :environment do
    result = DatabaseSetup::Provisioner.call(sqlserver_config)
    puts "Created: #{result[:created].join(', ')}"
    puts "Existing: #{result[:existing].join(', ')}"
  rescue DatabaseSetup::Provisioner::Error, DatabaseSetup::Client::Error => e
    abort "Provisioning failed: #{e.message}"
  end

  desc 'Full bootstrap: provision, create schema, migrate legacy data, verify'
  task setup: :environment do
    config = sqlserver_config
    result = DatabaseSetup::Bootstrap.call(config)
    DatabaseSetup::ConfigurationStore.save(config)
    DatabaseSetup::Runtime.establish_connections!(config)

    puts "Adapter:            #{result[:adapter]}"
    puts "Provisioned:        #{result[:provisioned][:created].join(', ')}"
    puts "Existing databases: #{result[:provisioned][:existing].join(', ')}"
    puts "Migrations applied: #{result[:schema][:migrated]}"
    puts "Rows imported:      #{result[:imported].inspect}"
    puts "Seeded:             #{result[:seeded].inspect}"
    puts "Migration run:      #{result[:migration_run]}"
    puts "Verification:       #{result[:verification][:ok] ? 'ok' : 'FAILED'}"
    result[:verification].each do |key, entry|
      next if key == :ok

      puts "  #{entry[:database]}: #{entry[:total_rows]} rows, missing: #{entry[:missing].join(', ').presence || 'none'}"
    end
  end

  desc 'Migrate legacy data into the SQL backend (requires an existing schema)'
  task migrate: :environment do
    config = sqlserver_config
    snapshot = DatabaseSetup::LegacyMigration.extract
    DatabaseSetup::Runtime.establish_connections!(config)

    run = MigrationRun.start!(
      run_key: 'legacy_json_sqlite_to_sql',
      source_adapter: 'sqlite',
      target_adapter: config.adapter,
      target_host: config.host
    )
    begin
      imported = DatabaseSetup::LegacyMigration.import(snapshot)
      run.finish!(tables_imported: imported.size, rows_imported: imported.values.sum)
    rescue StandardError => e
      run.fail!(e)
      raise
    end

    puts "Rows imported: #{imported.inspect}"
    puts "Migration run: #{run.id} (#{run.status})"
  end

  desc 'Verify databases, tables and row counts on the SQL backend'
  task verify: :environment do
    config = sqlserver_config
    report = DatabaseSetup::Verification.call(config)
    report.each do |key, entry|
      next if key == :ok

      state = entry[:ok] ? 'ok' : 'FAILED'
      puts "#{entry[:database]} (#{key}): #{state}, #{entry[:total_rows]} rows"
      puts "  missing: #{entry[:missing].join(', ')}" if entry[:missing].any?
      puts "  error:   #{entry[:error]}" if entry[:error]
    end
    abort 'Verification failed.' unless report[:ok]
  end

  desc 'Compare source (legacy) and target (SQL) row counts per table'
  task counts: :environment do
    config = sqlserver_config
    DatabaseSetup::Runtime.establish_connections!(config)

    DatabaseSetup::LegacyMigration::TABLES.each do |table|
      model = DatabaseSetup::LegacyMigration::MODELS.fetch(table)
      target = model.count
      puts format('%-32s %6d', table, target)
    end
  end
end

