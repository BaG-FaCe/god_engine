# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DatabaseSetup::Runtime do
  def with_env(vars)
    old = vars.keys.to_h { |key| [key, ENV[key]] }
    vars.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    old.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  describe '.adapter_name' do
    it 'defaults to the file based backend in the test environment' do
      with_env('DB_ADAPTER' => nil) do
        allow(DatabaseSetup::ConfigurationStore).to receive(:local_file_present?).and_return(false)
        expect(described_class.adapter_name).to eq('sqlite')
      end
    end

    it 'honours an explicitly selected adapter' do
      with_env('DB_ADAPTER' => 'mariadb') do
        expect(described_class.adapter_name).to eq('mariadb')
        expect(described_class.sql_backend?).to be(true)
        expect(described_class.sqlserver?).to be(false)
      end
    end

    it 'uses the adapter stored in the local configuration file' do
      with_env('DB_ADAPTER' => nil) do
        allow(DatabaseSetup::ConfigurationStore).to receive(:local_file_present?).and_return(true)
        allow(DatabaseSetup::ConfigurationStore)
          .to receive(:load).and_return(DatabaseSetup::Configuration.new(
                                          adapter: 'mariadb', host: 'db', username: 'u', password: 'p'
                                        ))
        expect(described_class.adapter_name).to eq('mariadb')
      end
    end

    it 'defaults to SQL Server outside the test environment' do
      with_env('DB_ADAPTER' => nil) do
        allow(DatabaseSetup::ConfigurationStore).to receive(:local_file_present?).and_return(false)
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
        expect(described_class.adapter_name).to eq('sqlserver')
      end
    end
  end

  describe '.setup_required?' do
    it 'is true on a SQL backend without configuration' do
      with_env('DB_ADAPTER' => 'sqlserver') do
        allow(DatabaseSetup::ConfigurationStore).to receive(:configured?).and_return(false)
        expect(described_class.setup_required?).to be(true)
      end
    end

    it 'is false once a configuration is stored' do
      with_env('DB_ADAPTER' => 'sqlserver') do
        allow(DatabaseSetup::ConfigurationStore).to receive(:configured?).and_return(true)
        expect(described_class.setup_required?).to be(false)
      end
    end

    it 'is false on the file based backend' do
      with_env('DB_ADAPTER' => 'sqlite') do
        expect(described_class.setup_required?).to be(false)
      end
    end
  end
end
