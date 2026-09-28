# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DatabaseSetup::Configuration do
  let(:sqlserver) { described_class.new(host: 'srv', username: 'u', password: 'p') }
  let(:mariadb) do
    described_class.new(adapter: 'mariadb', host: 'db.example.com', username: 'u', password: 'p')
  end

  describe '#valid?' do
    it 'requires a supported adapter, host, username and a non-empty password' do
      expect(sqlserver).to be_valid
      expect(described_class.new(host: '', username: 'u', password: 'p')).not_to be_valid
      expect(described_class.new(host: 'srv', username: '', password: 'p')).not_to be_valid
      expect(described_class.new(host: 'srv', username: 'u', password: '')).not_to be_valid
      expect(described_class.new(host: 'srv', username: 'u', password: 'p', adapter: 'oracle')).not_to be_valid
    end
  end

  describe 'ports' do
    it 'defaults to the port of the selected backend' do
      expect(sqlserver.port).to eq(1433)
      expect(mariadb.port).to eq(3306)
      expect(described_class.new(host: 's', username: 'u', password: 'p', port: 1443).port).to eq(1443)
    end
  end

  describe '#databases' do
    it 'maps the four responsibilities to their database names' do
      expect(sqlserver.databases).to eq(
        productdata: 'productdata', users: 'users', events: 'events', logs: 'logs'
      )
      expect(sqlserver.database_names).to eq(%w[productdata users events logs])
      expect(described_class::REQUIRED_DATABASES).to eq(%w[productdata users events logs])
    end

    it 'allows custom database names' do
      config = described_class.new(
        host: 'srv', username: 'u', password: 'p',
        database: 'my_app', users_database: 'my_users',
        events_database: 'my_events', logs_database: 'my_logs'
      )
      expect(config.database_names).to eq(%w[my_app my_users my_events my_logs])
    end
  end

  describe '#redacted' do
    it 'never contains the password' do
      config = described_class.new(host: 'srv', username: 'u', password: 'topsecret')
      expect(config.redacted.values.map(&:to_s)).not_to include('topsecret')
      expect(config.redacted).not_to have_key(:password)
    end
  end

  describe '#adapter_spec' do
    it 'builds a sqlserver adapter spec' do
      spec = sqlserver.adapter_spec
      expect(spec[:adapter]).to eq('sqlserver')
      expect(spec[:database]).to eq('productdata')
      expect(spec[:host]).to eq('srv')
      expect(spec[:port]).to eq(1433)
    end

    it 'builds a mysql2 adapter spec for MariaDB' do
      spec = mariadb.adapter_spec(database: 'events')
      expect(spec[:adapter]).to eq('mysql2')
      expect(spec[:database]).to eq('events')
      expect(spec[:port]).to eq(3306)
    end
  end

  describe 'dialect helpers' do
    it 'uses the backend specific catalogue queries and identifier quoting' do
      expect(sqlserver.databases_sql).to include('sys.databases')
      expect(mariadb.databases_sql).to include('information_schema.schemata')
      expect(sqlserver.quote_identifier('users')).to eq('[users]')
      expect(mariadb.quote_identifier('users')).to eq('`users`')
    end
  end
end

