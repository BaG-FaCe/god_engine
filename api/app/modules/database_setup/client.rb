# frozen_string_literal: true

module DatabaseSetup
  # Uniform minimal SQL client over TinyTds (Microsoft SQL Server) and Mysql2
  # (MariaDB/MySQL development server).
  #
  # Kept deliberately free of ActiveRecord so it works during first-run setup,
  # before any Rails database connection exists. Both drivers are wrapped
  # behind the same tiny interface (`execute` returning string-keyed rows,
  # `close`) so the rest of the bootstrap code is backend-agnostic.
  #
  # The drivers are required lazily: a production SQL Server deployment never
  # loads mysql2 and vice versa.
  class Client
    class Error < StandardError; end

    # Materialised result set with the same surface the provisioning code uses.
    class Result
      include Enumerable

      def initialize(rows)
        @rows = rows
      end

      def each(&block)
        @rows.each(&block)
      end

      def do
        @rows.size
      end
    end

    def initialize(configuration, database: nil)
      @configuration = configuration
      @raw = open_driver(configuration, database)
    end

    # Executes the SQL eagerly and returns a Result with string-keyed rows.
    def execute(sql)
      raw_result = @configuration.sqlserver? ? @raw.execute(sql) : @raw.query(sql)
      Result.new(raw_result.to_a.map { |row| stringify_keys(row) })
    rescue StandardError => e
      raise Error, sanitize(e)
    end

    def close
      @raw.close
    rescue StandardError
      nil
    end

    private

    def open_driver(configuration, database)
      if configuration.sqlserver?
        require 'tiny_tds'
        TinyTds::Client.new(configuration.client_options(database: database))
      else
        require 'mysql2'
        Mysql2::Client.new(configuration.client_options(database: database))
      end
    rescue StandardError => e
      raise Error, sanitize(e)
    end

    def stringify_keys(row)
      row.each_with_object({}) { |(key, value), hash| hash[key.to_s] = value }
    end

    def sanitize(error)
      message = error.message.to_s
      message = message.gsub(@configuration.password, '***') if @configuration.password.present?
      message
    end
  end
end
