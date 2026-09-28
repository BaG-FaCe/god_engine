# frozen_string_literal: true

require 'rails_helper'
require 'sqlite3'
require 'tmpdir'

RSpec.describe DatabaseSetup::LegacySource do
  let(:tmpdir) { Dir.mktmpdir('legacy-source-test') }
  let(:db_path) { File.join(tmpdir, 'legacy.sqlite3') }
  subject(:source) { described_class.new(path: db_path) }

  after { FileUtils.remove_entry(tmpdir) if Dir.exist?(tmpdir) }

  describe '#present?' do
    it 'returns false when the sqlite file does not exist' do
      expect(source.present?).to be false
    end

    it 'returns true when the sqlite file exists' do
      SQLite3::Database.new(db_path).close
      expect(source.present?).to be true
    end
  end

  describe '#extract' do
    it 'raises when the file does not exist' do
      expect { source.extract(['users']) }.to raise_error(
        DatabaseSetup::LegacySource::Error, /legacy database not found/
      )
    end

    it 'extracts rows as string-keyed hashes and skips missing tables' do
      db = SQLite3::Database.new(db_path)
      db.execute('CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT, active INTEGER)')
      db.execute("INSERT INTO users (id, email, active) VALUES (1, 'user@example.com', 1)")
      db.execute("INSERT INTO users (id, email, active) VALUES (2, 'other@example.com', 0)")
      db.close

      snapshot = source.extract(%w[users non_existent_table])

      expect(snapshot.keys).to eq(['users'])
      expect(snapshot['users'].size).to eq(2)
      expect(snapshot['users'].first).to eq(
        'id' => 1,
        'email' => 'user@example.com',
        'active' => 1
      )
    end

    it 'rejects invalid table names to prevent injection' do
      SQLite3::Database.new(db_path).close

      expect { source.extract(['users; DROP TABLE users;--']) }.to raise_error(
        DatabaseSetup::LegacySource::Error, /invalid table name/
      )
    end
  end

  describe '#table_names' do
    it 'lists user-defined tables in the legacy database' do
      db = SQLite3::Database.new(db_path)
      db.execute('CREATE TABLE foo (id INTEGER)')
      db.execute('CREATE TABLE bar (id INTEGER)')
      db.close

      expect(source.table_names).to contain_exactly('foo', 'bar')
    end
  end

  describe '#row_count' do
    it 'returns the row count for an existing table' do
      db = SQLite3::Database.new(db_path)
      db.execute('CREATE TABLE items (id INTEGER)')
      db.execute('INSERT INTO items VALUES (1), (2), (3)')
      db.close

      expect(source.row_count('items')).to eq(3)
    end
  end
end
