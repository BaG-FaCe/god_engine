# frozen_string_literal: true

module DatabaseSetup
  # Immutable value object describing the SQL backend target.
  #
  # This is the single source of truth for how the four platform databases are
  # named and addressed. It deliberately never serialises the password by
  # accident: the only full representation is `#to_h`, used exclusively by the
  # credential store, while `#redacted` is what may appear in logs or responses.
  #
  # Two SQL backends are supported:
  #   * `sqlserver` - Microsoft SQL Server (TinyTds / activerecord-sqlserver-adapter),
  #     the production target.
  #   * `mariadb`   - MariaDB/MySQL (mysql2), used for the development/test server.
  class Configuration
    # The four logical databases the application's initialisation logic
    # guarantees. Responsibilities (documented in project_documentation/):
    #   productdata - products, projects, materials, costs, risk master data
    #   users       - application users / identity store
    #   events      - application events (risk events + notifications)
    #   logs        - persistent logs: audit trail, provider runs, migration runs
    REQUIRED_DATABASES = %w[productdata users events logs].freeze

    ADAPTERS = %w[sqlserver mariadb].freeze

    attr_reader :host, :port, :username, :password, :adapter, :database,
                :users_database, :events_database, :logs_database, :encrypt, :timeout

    def initialize(host:, username:, password:, port: nil, adapter: 'sqlserver',
                   database: 'productdata', users_database: 'users',
                   events_database: 'events', logs_database: 'logs',
                   encrypt: true, timeout: 15)
      @adapter = presence_or(adapter, 'sqlserver')
      @host = host.to_s.strip
      @username = username.to_s
      @password = password.to_s
      @port = Integer(port || default_port)
      @database = presence_or(database, 'productdata')
      @users_database = presence_or(users_database, 'users')
      @events_database = presence_or(events_database, 'events')
      @logs_database = presence_or(logs_database, 'logs')
      @encrypt = encrypt
      @timeout = Integer(timeout)
    end

    def valid?
      ADAPTERS.include?(adapter) && host.present? && username.present? &&
        !password.empty? && port.positive?
    end

    def sqlserver?
      adapter == 'sqlserver'
    end

    def mariadb?
      adapter == 'mariadb'
    end

    # The databases that must exist, keyed by responsibility. Order is stable.
    def databases
      {
        productdata: database,
        users: users_database,
        events: events_database,
        logs: logs_database
      }
    end

    def database_names
      databases.values
    end

    # Safe for logs / API responses: the password is masked.
    def redacted
      {
        adapter: adapter,
        host: host,
        port: port,
        username: username,
        database: database,
        users_database: users_database,
        events_database: events_database,
        logs_database: logs_database,
        encrypt: encrypt
      }
    end

    # Full representation used ONLY by the credential store. Never log this.
    def to_h
      {
        adapter: adapter,
        host: host,
        port: port,
        username: username,
        password: password,
        database: database,
        users_database: users_database,
        events_database: events_database,
        logs_database: logs_database,
        encrypt: encrypt,
        timeout: timeout
      }
    end

    # Connection spec for the ActiveRecord adapter.
    def adapter_spec(database: self.database)
      base = {
        host: host,
        port: port,
        username: username,
        password: password,
        database: database,
        pool: ENV.fetch('RAILS_MAX_THREADS') { 5 }
      }
      if sqlserver?
        base.merge(adapter: 'sqlserver', timeout: timeout * 1000, encrypt: encrypt)
      else
        base.merge(adapter: 'mysql2', connect_timeout: timeout, read_timeout: timeout)
      end
    end

    # Options understood by the low-level driver (TinyTds / Mysql2), used for
    # provisioning and probing. `database: nil` connects without selecting a
    # database (SQL Server falls back to `master`; MariaDB needs none).
    def client_options(database: nil)
      base = {
        host: host,
        port: port,
        username: username,
        password: password,
        connect_timeout: timeout,
        read_timeout: timeout
      }
      if sqlserver?
        base.merge(database: database || 'master', login_timeout: timeout, timeout: timeout,
                   encrypt: encrypt)
      else
        database ? base.merge(database: database) : base
      end
    end

    # --- Dialect helpers (the only backend-specific SQL in the codebase) -----

    def databases_sql
      if sqlserver?
        'SELECT name FROM sys.databases'
      else
        'SELECT schema_name AS name FROM information_schema.schemata'
      end
    end

    def version_sql
      if sqlserver?
        'SELECT @@VERSION AS version, DB_NAME() AS db'
      else
        'SELECT VERSION() AS version, DATABASE() AS db'
      end
    end

    def tables_sql
      if sqlserver?
        "SELECT TABLE_NAME AS name FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'"
      else
        'SELECT table_name AS name FROM information_schema.tables WHERE table_schema = DATABASE()'
      end
    end

    # Database/table names cannot be parameterised in DDL; identifiers are
    # validated before this is ever called (see Provisioner/Verification).
    def quote_identifier(name)
      sqlserver? ? "[#{name}]" : "`#{name}`"
    end

    private

    def default_port
      sqlserver? ? 1433 : 3306
    end

    def presence_or(value, fallback)
      value.to_s.strip.presence || fallback
    end
  end
end

