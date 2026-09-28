# frozen_string_literal: true

module DatabaseSetup
  # Maps every persistent table onto its logical database and resolves the
  # ActiveRecord connection that must be used for it.
  #
  # The application uses exactly four logical databases:
  #
  #   productdata - products/projects and all associated domain data
  #   users       - the identity store (application users)
  #   events      - application events (risk events, notifications)
  #   logs        - persistent logs (audit trail, provider runs, migration runs)
  #
  # Routing is *virtual*: when the SQL backend runs all four databases on one
  # server (SQL Server / MariaDB) each abstract record class holds its own
  # connection. On a single-database backend (SQLite fallback, test suite) all
  # classes inherit the primary connection, `routed?` is false and every table
  # simply lands in the primary database - which keeps the file-based
  # development setup working unchanged.
  module TableRouting
    # table name => logical database
    TABLE_DATABASE = {
      'users' => :users,
      'risk_events' => :events,
      'risk_event_metadata' => :events,
      'risk_notifications' => :events,
      'audit_logs' => :logs,
      'audit_log_changes' => :logs,
      'audit_log_metadata' => :logs,
      'risk_provider_runs' => :logs,
      'migration_runs' => :logs
    }.freeze

    # abstract ActiveRecord classes that own a separate connection
    CONNECTION_CLASSES = {
      users: 'UsersRecord',
      events: 'EventsRecord',
      logs: 'LogsRecord'
    }.freeze

    DEFAULT_DATABASE = :productdata

    # Framework tables that only exist in the primary database.
    FRAMEWORK_TABLES = %w[schema_migrations ar_internal_metadata].freeze

    # Tables that live in `productdata`. Used for verification/reporting.
    PRODUCTDATA_TABLES = %w[
      projects
      suppliers
      materials
      material_risk_profiles
      alternative_suppliers
      material_documents
      monthly_costs
      sales_forecasts
      labor_costs
      fixed_costs
      overhead_rules
      cost_templates
      cost_template_items
      pricing_scenarios
      pricing_scenario_results
      pricing_scenario_warnings
      risk_assessments
      risk_assessment_dimensions
      risk_assessment_data_sources
      risk_provider_configs
      risk_score_snapshots
      sanctions_entries
      sanctions_entry_aliases
      sanctions_entry_identifiers
    ].freeze

    class << self
      def database_for(table)
        TABLE_DATABASE.fetch(table.to_s, DEFAULT_DATABASE)
      end

      # All tables expected in the given logical database (excluding the
      # framework tables `schema_migrations` / `ar_internal_metadata`, which
      # only exist in the primary database).
      def tables_for(database)
        case database.to_sym
        when :productdata then PRODUCTDATA_TABLES
        else TABLE_DATABASE.select { |_table, db| db == database.to_sym }.keys
        end
      end

      # All tables expected in the given logical database, including the
      # framework tables of the primary database.
      def expected_tables_for(database)
        tables = tables_for(database)
        database.to_sym == DEFAULT_DATABASE ? tables + FRAMEWORK_TABLES : tables
      end

      # True when the given logical database is physically separate from the
      # primary database on the current connection setup.
      def routed?(database)
        klass = abstract_class_for(database)
        return false unless klass

        klass.connection_pool.db_config.database !=
          ActiveRecord::Base.connection_pool.db_config.database
      end

      # The connection a table must be created in / written through.
      def connection_for(table, fallback:)
        database = database_for(table)
        return fallback if database == DEFAULT_DATABASE
        return fallback unless routed?(database)

        abstract_class_for(database).connection
      end

      # True when the two tables end up in physically different databases, so a
      # database-level foreign key cannot be created between them (the
      # relationship is then enforced by the application / documented as
      # logical).
      def cross_database?(from_table, to_table)
        from = database_for(from_table)
        to = database_for(to_table)
        return false if from == to

        routed?(from) || routed?(to)
      end

      private

      def abstract_class_for(database)
        name = CONNECTION_CLASSES[database.to_sym]
        name && name.constantize
      end
    end
  end
end
