# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DatabaseSetup::Verification do
  let(:config) { DatabaseSetup::Configuration.new(host: 'srv', username: 'u', password: 'p') }

  # Builds a client factory that reports exactly the given tables (and 7 rows
  # per table) for each logical database.
  def client_factory(tables_by_database)
    lambda do |database|
      FakeSqlClient.new(
        'INFORMATION_SCHEMA.TABLES' => tables_by_database.fetch(database).map { |name| { 'name' => name } },
        'COUNT(*)' => [{ 'count' => 7 }]
      )
    end
  end

  def all_tables
    DatabaseSetup::TableRouting.tables_for(:productdata)
  end

  it 'reports ok when every expected table exists' do
    tables = {
      'productdata' => DatabaseSetup::TableRouting.expected_tables_for(:productdata),
      'users' => %w[sessions users],
      'events' => %w[risk_events risk_event_metadata risk_notifications],
      'logs' => %w[audit_logs audit_log_changes audit_log_metadata risk_provider_runs migration_runs]
    }

    report = described_class.new(config, client_factory: client_factory(tables)).call

    expect(report[:ok]).to be(true)
    expect(report[:users][:missing]).to be_empty
    expect(report[:users][:tables]).to eq('sessions' => 7, 'users' => 7)
    expect(report[:events][:total_rows]).to eq(3 * 7)
    expect(report[:logs][:total_rows]).to eq(5 * 7)
  end

  it 'reports the missing tables of a partially provisioned database' do
    tables = {
      'productdata' => DatabaseSetup::TableRouting.tables_for(:productdata),
      'users' => %w[sessions users],
      'events' => %w[risk_events],
      'logs' => %w[audit_logs]
    }

    report = described_class.new(config, client_factory: client_factory(tables)).call

    expect(report[:ok]).to be(false)
    expect(report[:events][:missing]).to contain_exactly('risk_event_metadata', 'risk_notifications')
    expect(report[:logs][:missing]).to contain_exactly(
      'audit_log_changes', 'audit_log_metadata', 'risk_provider_runs', 'migration_runs'
    )
  end

  it 'never leaks the password in an error report' do
    failing = ->(_database) { raise DatabaseSetup::Client::Error, 'access denied for secret-pw' }
    config_with_secret = DatabaseSetup::Configuration.new(
      host: 'srv', username: 'u', password: 'secret-pw'
    )

    report = described_class.new(config_with_secret, client_factory: failing).call

    expect(report[:ok]).to be(false)
    expect(report[:productdata][:error]).to eq('access denied for ***')
  end

  describe '.failure_message' do
    it 'summarises missing tables and errors' do
      message = described_class.failure_message(
        ok: false,
        users: { ok: false, missing: %w[users], error: nil },
        logs: { ok: false, missing: [], error: 'permission denied' }
      )

      expect(message).to include('users: missing tables users')
      expect(message).to include('logs: permission denied')
    end
  end
end
