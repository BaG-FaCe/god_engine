# frozen_string_literal: true

module DatabaseSetup
  # Creates the schema of all four logical databases by running the
  # application's own migrations (the single source of truth for the schema).
  #
  # This is a one-time bootstrap step, performed while the app is not yet
  # serving traffic. It first establishes the four ActiveRecord connections
  # (productdata / users / events / logs); the migrations themselves route each
  # table to the connection that owns it (`DatabaseSetup::PlatformMigration`),
  # so every table lands in its required database.
  class SchemaLoader
    # @return [Hash] summary of migrated/current migrations.
    def self.call(configuration)
      new(configuration).call
    end

    def initialize(configuration)
      @configuration = configuration
    end

    def call
      Runtime.establish_connections!(@configuration)

      # Rails 8 builds the migration context (and its schema_migrations bookkeeping)
      # from the connection pool, so the versions are tracked in the primary
      # database while each migration routes its DDL to the owning database.
      context = ActiveRecord::Base.connection_pool.migration_context
      context.migrate

      statuses = context.migrations_status
      {
        migrated: statuses.count { |(status, _version, _name)| status == 'up' },
        pending: statuses.count { |(status, _version, _name)| status == 'down' }
      }
    end
  end
end

