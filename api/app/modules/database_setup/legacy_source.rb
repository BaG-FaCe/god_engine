# frozen_string_literal: true

require 'sqlite3'

module DatabaseSetup
  # Reads the *legacy* persistence store - the file based SQLite database the
  # application used before the SQL backend was introduced.
  #
  # This source is deliberately independent of ActiveRecord: after a restart the
  # models may already be connected to the SQL backend (or being migrated away
  # from it), while the snapshot of the legacy data must always come from the
  # original file. Only `SELECT` statements are issued, so the legacy file stays
  # untouched and the migration remains reversible from a data-recovery
  # perspective.
  #
  # The path defaults to `storage/<environment>.sqlite3` and can be overridden
  # with `LEGACY_SQLITE_PATH`.
  class LegacySource
    class Error < StandardError; end

    def initialize(path: nil)
      @path = Pathname.new(path || ENV['LEGACY_SQLITE_PATH'] || default_file)
    end

    attr_reader :path

    def present?
      File.exist?(@path)
    end

    # @param tables [Array<String>] tables to read (in dependency order).
    # @return [Hash{String => Array<Hash>}] string-keyed column names, exactly
    #   the shape `insert_all` expects.
    def extract(tables)
      raise Error, "legacy database not found at #{@path}" unless present?

      with_database do |db|
        tables.each_with_object({}) do |table, snapshot|
          next unless table_exists?(db, table)

          snapshot[table] = rows(db, table)
        end
      end
    end

    def table_names
      with_database do |db|
        db.execute("SELECT name FROM sqlite_master WHERE type = 'table'").map do |row|
          row['name'].to_s
        end
      end
    end

    def row_count(table)
      with_database { |db| db.get_first_value("SELECT COUNT(*) FROM #{quote(table)}").to_i }
    end

    private

    def default_file
      Rails.root.join('storage', "#{Rails.env}.sqlite3")
    end

    def with_database
      db = SQLite3::Database.new(@path.to_s)
      db.busy_timeout = 5_000
      db.results_as_hash = true
      yield db
    rescue SQLite3::Exception => e
      raise Error, "#{e.class}: #{e.message}"
    ensure
      db&.close
    end

    # Identifier safety: table names come from the fixed TABLES list, but the
    # pattern is validated anyway (they are interpolated into SQL).
    def table_exists?(db, table)
      db.get_first_value(
        "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = #{quote_literal(table)}"
      ).to_i.positive?
    end

    def rows(db, table)
      db.execute("SELECT * FROM #{quote(table)}").map do |row|
        row.each_with_object({}) do |(key, value), hash|
          hash[key.to_s] = value if key.is_a?(String)
        end
      end
    end

    def quote(table)
      validate_table_name!(table)
      "\"#{table}\""
    end

    def quote_literal(value)
      validate_table_name!(value)
      "'#{value}'"
    end

    def validate_table_name!(name)
      return name.to_s if name.to_s.match?(/\A[a-z0-9_]+\z/)

      raise Error, "invalid table name: #{name.inspect}"
    end
  end
end
