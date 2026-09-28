# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DatabaseSetup::Connection do
  let(:config) do
    DatabaseSetup::Configuration.new(host: 'srv', username: 'u', password: 'topsecret')
  end

  describe '.test!' do
    it 'returns server version and authenticated database on success' do
      client = FakeSqlClient.new('@@VERSION' => [{ 'version' => "Microsoft SQL Server 2022\n", 'db' => 'master' }])
      result = described_class.new(config, client: client).test!

      expect(result[:ok]).to be(true)
      expect(result[:serverVersion]).to eq('Microsoft SQL Server 2022')
      expect(result[:database]).to eq('master')
    end

    it 'sanitises the password out of error messages' do
      client = FakeSqlClient.new({})
      allow(client).to receive(:execute).and_raise(TinyTds::Error, "Login failed for user 'u' with password 'topsecret'")

      expect { described_class.new(config, client: client).test! }
        .to raise_error(DatabaseSetup::Connection::Error, /Login failed.*\*\*\*/)
    end
  end

  describe '.databases' do
    it 'lists existing database names (lowercased)' do
      client = FakeSqlClient.new('sys.databases' => [{ 'name' => 'master' }, { 'name' => 'ProductData' }])
      expect(described_class.new(config, client: client).databases).to eq(%w[master productdata])
    end
  end
end
