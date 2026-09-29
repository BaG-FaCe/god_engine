# frozen_string_literal: true

module DatabaseSetup
  # Verifies the *result* of the bootstrap on the SQL backend.
  #
  # A migration is not complete just because the INSERT statements returned
  # successfully, so the bootstrap refuses to report success while this check
  # fails: every required database must exist, every expected table must be
  # present and row counts must be readable.
  class Verification
    class Error < StandardError; end

    def self.call(configuration)
      new(configuration).call
    end

    def initialize(configuration, client_factory: nil)
      @configuration = configuration
      @client_factory = client_factory ||
                        ->(database) { Client.new(configuration, database: database) }
    end

    # @return [Hash] per logical database: `database`, `ok`, `tables` (name =>
    #   row count), `total_rows`, `missing`. `:ok` is the overall result.
    def call
      report = @configuration.databases.to_h do |logical, database|
        [logical, verify_database(logical, database)]
      end
      report[:ok] = report.values.all? { |entry| entry[:ok] }
      report
    end

    def self.failure_message(report)
      problems = report
                 .reject { |key, _value| key == :ok }
                 .reject { |_key, entry| entry[:ok] }
                 .map { |key, entry| "#{key}: #{problem_detail(entry)}" }
      "migration verification failed (#{problems.join('; ')})"
    end

    def self.problem_detail(entry)
      return entry[:error] if entry[:error]

      [
        ("missing tables #{entry[:missing].join(', ')}" if entry[:missing].present?),
        ("unexpected tables #{entry[:unexpected].join(', ')}" if entry[:unexpected].present?)
      ].compact.join('; ')
    end

    private

    def verify_database(logical, database)
      expected = TableRouting.expected_tables_for(logical)
      client = @client_factory.call(database)
      present = client.execute(@configuration.tables_sql).each.map { |row| row['name'].to_s.downcase }
      counts = expected.to_h do |table|
        [table, present.include?(table) ? row_count(client, table) : nil]
      end
      missing = expected.reject { |table| present.include?(table) }
      # Tables that physically exist here but belong to another database: a
      # signal that the routing (or the migration history) is inconsistent.
      unexpected = present.reject { |table| expected.include?(table) }
      {
        database: database,
        ok: missing.empty? && unexpected.empty?,
        tables: counts,
        total_rows: counts.values.compact.sum,
        missing: missing,
        unexpected: unexpected
      }
    rescue StandardError => e
      {
        database: database,
        ok: false,
        error: sanitize(e),
        tables: {},
        total_rows: 0,
        missing: expected || [],
        unexpected: []
      }
    ensure
      client&.close
    end

    def row_count(client, table)
      sql = "SELECT COUNT(*) AS count FROM #{@configuration.quote_identifier(table)}"
      client.execute(sql).each.first['count'].to_i
    end

    def sanitize(error)
      message = error.message.to_s
      message = message.gsub(@configuration.password, '***') if @configuration.password.present?
      message
    end
  end
end
