# frozen_string_literal: true

# Minimal stand-in for TinyTds::Client used to exercise the SQL Server
# bootstrap classes without a live server. Routes SQL fragments to canned rows
# and records any CREATE DATABASE statements.
class FakeSqlResult
  def initialize(rows)
    @rows = rows
  end

  def each
    return @rows.each unless block_given?

    @rows.each { |row| yield row }
  end

  def do
    :done
  end
end

class FakeSqlClient
  attr_reader :queries, :created_databases

  def initialize(rows = {})
    @rows = rows
    @queries = []
    @created_databases = []
  end

  def execute(sql)
    @queries << sql
    if sql.match?(/\ACREATE DATABASE/i)
      @created_databases << sql
      return FakeSqlResult.new([])
    end

    match = @rows.find { |fragment, _result| sql.include?(fragment) }
    FakeSqlResult.new(match ? match.last : [])
  end

  def close; end
end
