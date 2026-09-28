# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DatabaseSetup::Provisioner do
  let(:config) do
    DatabaseSetup::Configuration.new(host: 'srv', username: 'u', password: 'p')
  end

  it 'creates only the missing databases and reports them' do
    client = FakeSqlClient.new('sys.databases' => [{ 'name' => 'master' }, { 'name' => 'productdata' }])

    result = described_class.new(config, client: client).call

    expect(result[:existing]).to eq(%w[productdata])
    expect(result[:created]).to eq(%w[users events logs])
    expect(client.created_databases).to contain_exactly(
      'CREATE DATABASE [users]', 'CREATE DATABASE [events]', 'CREATE DATABASE [logs]'
    )
  end

  it 'creates nothing when all four databases already exist' do
    client = FakeSqlClient.new('sys.databases' => [
                                 { 'name' => 'master' }, { 'name' => 'productdata' },
                                 { 'name' => 'users' }, { 'name' => 'events' }, { 'name' => 'logs' }
                               ])

    result = described_class.new(config, client: client).call

    expect(result[:created]).to be_empty
    expect(client.created_databases).to be_empty
  end

  it 'provides an explicit character set for MariaDB databases' do
    mariadb = DatabaseSetup::Configuration.new(
      adapter: 'mariadb', host: 'db', username: 'u', password: 'p'
    )
    client = FakeSqlClient.new('information_schema.schemata' => [{ 'name' => 'productdata' }])

    result = described_class.new(mariadb, client: client).call

    expect(result[:created]).to eq(%w[users events logs])
    expect(client.created_databases).to include(
      'CREATE DATABASE `events` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'
    )
  end

  it 'rejects invalid database names before interpolating SQL' do
    invalid = DatabaseSetup::Configuration.new(host: 'srv', username: 'u', password: 'p', database: 'bad;DROP')
    client = FakeSqlClient.new('sys.databases' => [])

    expect { described_class.new(invalid, client: client).call }
      .to raise_error(ArgumentError, /invalid database name/)
  end
end

