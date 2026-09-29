# frozen_string_literal: true

module DatabaseSetup
  # Runtime helpers for deciding which database backend is active and for
  # switching the ActiveRecord connections to the configured SQL backend.
  #
  # Default behaviour: the application requires a configured SQL backend. There
  # is no silent SQLite fallback for persistent data any more - as long as no
  # configuration exists the first-run setup screen is shown and the API refuses
  # to serve persistent data (`setup_required?`).
  #
  # Explicit escape hatches:
  #   * `DB_ADAPTER=sqlite` - keep the file based backend (development/debugging).
  #   * test environment      - stays on SQLite, so the suite needs no server.
  class Runtime
    VALID_ADAPTERS = %w[sqlite sqlserver mariadb].freeze
    DEFAULT_ADAPTER = 'sqlserver'

    class << self
      # `sqlite`, `sqlserver` or `mariadb`.
      def adapter_name
        explicit = ENV['DB_ADAPTER'].to_s.strip
        return explicit if VALID_ADAPTERS.include?(explicit)
        return stored_adapter if ConfigurationStore.local_file_present?
        return 'sqlite' if Rails.env.test?

        DEFAULT_ADAPTER
      end

      # True for any configured SQL backend (SQL Server or MariaDB).
      def sql_backend?
        adapter_name != 'sqlite'
      end

      # Kept as an explicit predicate for the production target.
      def sqlserver?
        adapter_name == 'sqlserver'
      end

      # True when the app is meant to run on a SQL backend but no configuration
      # exists yet - the first-run setup screen must be shown.
      def setup_required?
        sql_backend? && !ConfigurationStore.configured?
      end

      # Switches every ActiveRecord connection to the configured SQL backend:
      # the primary connection (productdata) plus the three secondary pools that
      # own the users / events / logs databases.
      def establish_connections!(configuration)
        ActiveRecord::Base.establish_connection(
          configuration.adapter_spec(database: configuration.database)
        )
        {
          'UsersRecord' => configuration.users_database,
          'EventsRecord' => configuration.events_database,
          'LogsRecord' => configuration.logs_database
        }.each do |class_name, database|
          class_name.constantize.establish_connection(configuration.adapter_spec(database: database))
        end
      end

      private

      def stored_adapter
        ConfigurationStore.load&.adapter || DEFAULT_ADAPTER
      end
    end
  end
end

