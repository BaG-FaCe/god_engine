# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DatabaseSetup::Bootstrap do
  let(:config) { DatabaseSetup::Configuration.new(host: 'srv', username: 'u', password: 'p') }
  let(:run) { instance_double(MigrationRun, id: 'run-1', finished?: false) }

  it 'runs extract → provision → schema → import → seed → verify and records the run' do
    order = []
    allow(MigrationRun).to receive(:start!) { order << :start_run; run }
    allow(run).to receive(:finish!)
    allow(run).to receive(:fail!)
    allow(DatabaseSetup::LegacyMigration).to receive(:extract) { order << :extract; { 'users' => [] } }
    allow(DatabaseSetup::Provisioner).to receive(:call) { order << :provision; { created: %w[users events logs] } }
    allow(DatabaseSetup::SchemaLoader).to receive(:call) { order << :schema; { migrated: 9, pending: 0 } }
    allow(DatabaseSetup::LegacyMigration).to receive(:import) { order << :import; { 'users' => 2, 'projects' => 1 } }
    allow(DatabaseSetup::Seeder).to receive(:call) { order << :seed; { users: 1, projects: 1, materials: 2 } }
    allow(DatabaseSetup::Verification).to receive(:call) { order << :verify; { ok: true, productdata: { ok: true } } }

    result = described_class.call(config)

    expect(order).to eq(%i[extract provision schema start_run import seed verify])
    expect(result[:adapter]).to eq('sqlserver')
    expect(result[:schema][:migrated]).to eq(9)
    expect(result[:seeded]).to eq(users: 1, projects: 1, materials: 2)
    expect(result[:verification][:ok]).to be(true)
    expect(result[:migration_run]).to eq('run-1')
    expect(run).to have_received(:finish!).with(tables_imported: 2, rows_imported: 3)
  end

  it 'records a failed run and raises when verification reports missing tables' do
    allow(MigrationRun).to receive(:start!).and_return(run)
    allow(run).to receive(:finish!)
    allow(run).to receive(:fail!)
    allow(DatabaseSetup::LegacyMigration).to receive(:extract).and_return({})
    allow(DatabaseSetup::Provisioner).to receive(:call).and_return(created: [])
    allow(DatabaseSetup::SchemaLoader).to receive(:call).and_return(migrated: 9, pending: 0)
    allow(DatabaseSetup::LegacyMigration).to receive(:import).and_return({})
    allow(DatabaseSetup::Seeder).to receive(:call).and_return(users: 0, projects: 0, materials: 0)
    allow(DatabaseSetup::Verification).to receive(:call).and_return(
      ok: false,
      users: { database: 'users', ok: false, missing: %w[users], error: nil, total_rows: 0 }
    )

    expect { described_class.call(config) }
      .to raise_error(DatabaseSetup::Verification::Error, /missing tables users/)
    expect(run).to have_received(:fail!)
    expect(run).not_to have_received(:finish!)
  end
end


