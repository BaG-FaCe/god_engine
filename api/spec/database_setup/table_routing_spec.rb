# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DatabaseSetup::TableRouting do
  describe '.database_for' do
    it 'maps every persistent table to its logical database' do
      expect(described_class.database_for('projects')).to eq(:productdata)
      expect(described_class.database_for('materials')).to eq(:productdata)
      expect(described_class.database_for('pricing_scenario_results')).to eq(:productdata)
      expect(described_class.database_for('users')).to eq(:users)
      expect(described_class.database_for('risk_events')).to eq(:events)
      expect(described_class.database_for('risk_event_metadata')).to eq(:events)
      expect(described_class.database_for('risk_notifications')).to eq(:events)
      expect(described_class.database_for('audit_logs')).to eq(:logs)
      expect(described_class.database_for('audit_log_changes')).to eq(:logs)
      expect(described_class.database_for('audit_log_metadata')).to eq(:logs)
      expect(described_class.database_for('risk_provider_runs')).to eq(:logs)
      expect(described_class.database_for('migration_runs')).to eq(:logs)
    end
  end

  describe '.tables_for' do
    it 'lists the tables expected in each database' do
      expect(described_class.tables_for(:users)).to eq(%w[users])
      expect(described_class.tables_for(:events))
        .to contain_exactly('risk_events', 'risk_event_metadata', 'risk_notifications')
      expect(described_class.tables_for(:logs)).to contain_exactly(
        'audit_logs', 'audit_log_changes', 'audit_log_metadata', 'risk_provider_runs', 'migration_runs'
      )
      expect(described_class.tables_for(:productdata))
        .to include('projects', 'materials', 'pricing_scenario_results', 'risk_provider_configs')
      expect(described_class.tables_for(:users) & described_class.tables_for(:productdata)).to be_empty
    end
  end

  describe 'single database backend (test/SQLite)' do
    it 'routes nothing, so every table uses the primary connection' do
      connection = ActiveRecord::Base.connection

      expect(described_class.routed?(:users)).to be(false)
      expect(described_class.routed?(:events)).to be(false)
      expect(described_class.connection_for('users', fallback: connection)).to eq(connection)
      expect(described_class.connection_for('risk_events', fallback: connection)).to eq(connection)
      expect(described_class.cross_database?('risk_events', 'materials')).to be(false)
    end

    it 'keeps foreign keys between logical databases while they share one database' do
      expect(described_class.cross_database?('audit_log_changes', 'audit_logs')).to be(false)
      expect(described_class.cross_database?('risk_event_metadata', 'risk_events')).to be(false)
    end
  end

  describe 'model placement' do
    it 'binds each model to the record class of its logical database' do
      expect(User.superclass).to eq(UsersRecord)
      expect(RiskEvent.superclass).to eq(EventsRecord)
      expect(RiskEventMetadatum.superclass).to eq(EventsRecord)
      expect(RiskNotification.superclass).to eq(EventsRecord)
      expect(AuditLog.superclass).to eq(LogsRecord)
      expect(AuditLogChange.superclass).to eq(LogsRecord)
      expect(AuditLogMetadatum.superclass).to eq(LogsRecord)
      expect(RiskProviderRun.superclass).to eq(LogsRecord)
      expect(MigrationRun.superclass).to eq(LogsRecord)

      expect(Project.superclass).to eq(ApplicationRecord)
      expect(Material.superclass).to eq(ApplicationRecord)
    end
  end
end
