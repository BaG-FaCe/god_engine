# frozen_string_literal: true

module DatabaseSetup
  # Ensures the four required databases exist on the SQL backend.
  #
  # Idempotent and non-destructive: it only ever *creates* missing databases,
  # never drops or alters existing ones (a restart of the application must not
  # recreate or corrupt existing data).
  class Provisioner
    class Error < StandardError; end

    # @return [Hash] `existing` (present), `created` (newly created), `missing`
    #   (still missing after the run, normally empty).
    def self.call(configuration)
      new(configuration).call
    end

    def initialize(configuration, client: nil)
      @configuration = configuration
      @client = client
    end

    def call
      client = @client || Client.new(@configuration, database: nil)
      existing = existing_databases(client)
      missing = @configuration.database_names.reject { |name| existing.include?(name) }
      created = []

      missing.each do |name|
        client.execute(create_database_sql(name))
        created << name
      end

      {
        existing: @configuration.database_names & existing,
        created: created,
        missing: missing - created
      }
    rescue ArgumentError
      raise
    rescue StandardError => e
      raise Error, sanitize(e)
    ensure
      client&.close if @client.nil? && client.respond_to?(:close)
    end

    private

    def existing_databases(client)
      client.execute(@configuration.databases_sql).each.map { |row| row['name'].to_s.downcase }
    end

    def create_database_sql(name)
      quoted = quote_identifier(name)
      if @configuration.sqlserver?
        "CREATE DATABASE #{quoted}"
      else
        "CREATE DATABASE #{quoted} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
      end
    end

    # Database names cannot be parameterised in DDL; validate strictly so the
    # identifier is safe to interpolate.
    def quote_identifier(name)
      unless name.to_s.match?(/\A[a-zA-Z0-9_]+\z/)
        raise ArgumentError, "invalid database name: #{name.inspect}"
      end

      @configuration.quote_identifier(name)
    end

    def sanitize(error)
      message = error.message.to_s
      message = message.gsub(@configuration.password, '***') if @configuration.password.present?
      message
    end
  end
end

