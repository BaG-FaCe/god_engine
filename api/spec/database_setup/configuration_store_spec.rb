# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DatabaseSetup::ConfigurationStore do
  let(:config) do
    DatabaseSetup::Configuration.new(host: 'srv', username: 'u', password: 'p', port: 1433)
  end

  let(:dir) { Dir.mktmpdir('sqlserver-store') }
  let(:tmp_file) { File.join(dir, 'sqlserver.local.yml') }

  before do
    allow(described_class).to receive(:path).and_return(tmp_file)
  end

  after do
    FileUtils.remove_entry(dir) if dir && File.directory?(dir)
  end

  describe '.save / .load / .clear' do
    it 'round-trips a configuration through the local file' do
      described_class.save(config)

      expect(described_class.local_file_present?).to be(true)
      loaded = described_class.load
      expect(loaded.host).to eq('srv')
      expect(loaded.username).to eq('u')
      expect(loaded.password).to eq('p')
      expect(loaded.database).to eq('productdata')
      expect(loaded.logs_database).to eq('logs')
      expect(loaded.events_database).to eq('events')
      expect(loaded.users_database).to eq('users')
    end

    it 'clear removes the file' do
      described_class.save(config)
      described_class.clear
      expect(described_class.local_file_present?).to be(false)
      expect(described_class.load).to be_nil
    end
  end

  describe '.from_env' do
    it 'reads configuration from environment variables when present' do
      with_env(
        'SQL_SERVER' => 'env-srv',
        'SQL_USER' => 'env-user',
        'SQL_PASSWORD' => 'env-pass',
        'SQL_PORT' => '1433',
        'SQL_DATABASE' => 'custom_app'
      ) do
        loaded = described_class.from_env
        expect(loaded.host).to eq('env-srv')
        expect(loaded.password).to eq('env-pass')
        expect(loaded.database).to eq('custom_app')
      end
    end
  end

  describe '.configured?' do
    it 'is false when nothing is configured' do
      with_env('SQL_SERVER' => nil, 'SQL_USER' => nil, 'SQL_PASSWORD' => nil) do
        expect(described_class.configured?).to be(false)
      end
    end

    it 'is true when the local file exists' do
      described_class.save(config)
      expect(described_class.configured?).to be(true)
    end
  end

  def with_env(vars)
    old = vars.keys.to_h { |key| [key, ENV[key]] }
    vars.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    old.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
