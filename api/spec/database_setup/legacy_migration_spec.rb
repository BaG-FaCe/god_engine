# frozen_string_literal: true

require 'rails_helper'
require 'sqlite3'
require 'tmpdir'

RSpec.describe DatabaseSetup::LegacyMigration do
  describe '.extract' do
    it 'snapshots every table using the legacy source, preserving UUID keys and relationships' do
      Dir.mktmpdir('legacy-extract') do |tmpdir|
        db_path = File.join(tmpdir, 'legacy.sqlite3')
        db = SQLite3::Database.new(db_path)
        described_class::TABLES.each do |table|
          db.execute("CREATE TABLE #{table} (id TEXT PRIMARY KEY, name TEXT, project_id TEXT)")
        end
        project_id = SecureRandom.uuid
        material_id = SecureRandom.uuid
        db.execute("INSERT INTO projects (id, name) VALUES ('#{project_id}', 'Project 1')")
        db.execute("INSERT INTO materials (id, name, project_id) VALUES ('#{material_id}', 'ALU-1', '#{project_id}')")
        db.close

        source = DatabaseSetup::LegacySource.new(path: db_path)
        snapshot = described_class.extract(source: source)

        expect(snapshot.keys).to eq(described_class::TABLES)
        expect(snapshot['projects'].size).to eq(1)
        expect(snapshot['materials'].size).to eq(1)

        migrated = snapshot['materials'].first
        expect(migrated['id']).to eq(material_id)
        expect(migrated['project_id']).to eq(project_id)
      end
    end
  end

  describe 'import (write-back and idempotency)' do
    it 're-imports extracted rows preserving UUID keys and relationships without duplicating' do
      project_id = SecureRandom.uuid
      material_id = SecureRandom.uuid
      profile_id = SecureRandom.uuid

      snapshot = {
        'projects' => [
          {
            'id' => project_id,
            'name' => 'Imported Project',
            'status' => 'active',
            'country' => 'DE',
            'currency' => 'EUR',
            'units_per_month' => 100,
            'batch_size' => 10,
            'risk_refresh_interval_hours' => 24,
            'created_at' => Time.current,
            'updated_at' => Time.current
          }
        ],
        'materials' => [
          {
            'id' => material_id,
            'project_id' => project_id,
            'name' => 'ALU-2020',
            'unit' => 'Stk',
            'unit_price_cents' => 450,
            'quantity' => 1,
            'lead_time_value' => 7,
            'lead_time_unit' => 'days',
            'material_type' => 'raw_material',
            'created_at' => Time.current,
            'updated_at' => Time.current
          }
        ],
        'material_risk_profiles' => [
          {
            'id' => profile_id,
            'material_id' => material_id,
            'origin_country' => 'DE',
            'shipping_route' => 'direct',
            'transport_mode' => 'road',
            'manual_risk_level' => 'low',
            'created_at' => Time.current,
            'updated_at' => Time.current
          }
        ]
      }

      # First import writes all rows.
      imported = described_class.import(snapshot)
      expect(imported['projects']).to eq(1)
      expect(imported['materials']).to eq(1)
      expect(imported['material_risk_profiles']).to eq(1)

      # Re-importing over data that already exists inserts nothing (idempotent).
      expect(described_class.import(snapshot).values.sum).to eq(0)

      # Primary keys and relationships survived.
      restored = Material.find(material_id)
      expect(restored.name).to eq('ALU-2020')
      expect(restored.project_id).to eq(project_id)
    end
  end
end

