# frozen_string_literal: true

module DatabaseSetup
  # Low-level SQL backend connectivity checks.
  #
  # Backend-agnostic: the actual driver (TinyTds for Microsoft SQL Server,
  # Mysql2 for MariaDB) is encapsulated in `DatabaseSetup::Client`. Kept free of
  # ActiveRecord so it works during first-run setup, before any Rails database
  # connection exists. Every error message is sanitised so the supplied password
  # or a full connection string can never leak into logs or the API response.
  class Connection
    class Error < StandardError; end

    # @return [Hash] connectivity + authentication probe result.
    def self.test!(configuration)
      new(configuration).test!
    end

    # @return [Array<String>] names of the databases currently on the server.
    def self.databases(configuration)
      new(configuration).databases
    end

    def initialize(configuration, client: nil)
      @configuration = configuration
      @client = client
    end

    # Verifies the server is reachable and the credentials authenticate, and
    # reports the server version. Connects without selecting a database (SQL
    # Server lands on `master`, which always exists).
    def test!
      with_client do |client|
        row = client.execute(@configuration.version_sql).each.first || {}
        {
          ok: true,
          adapter: @configuration.adapter,
          serverVersion: row['version'].to_s.split("\n").first.to_s.strip,
          database: row['db'].to_s,
          host: @configuration.host,
          username: @configuration.username
        }
      end
    end

    # Read-only listing of existing database names (used to report which of the
    # four required databases are missing without creating anything).
    def databases
      with_client do |client|
        client.execute(@configuration.databases_sql).each.map { |row| row['name'].to_s.downcase }
      end
    end

    private

    def with_client
      client = @client || Client.new(@configuration, database: nil)
      yield client
    rescue StandardError => e
      raise Error, sanitize(e)
    ensure
      # Only close clients we created ourselves so injected (test) clients stay open.
      client&.close if @client.nil? && client.respond_to?(:close)
    end

    def sanitize(error)
      message = error.message.to_s
      message = message.gsub(@configuration.password, '***') if @configuration.password.present?
      message
    end
  end
end

