# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'System Setup API', type: :request do
  describe 'GET /api/v1/system/setup/status' do
    it 'reports the active adapter and setup state without leaking secrets' do
      get '/api/v1/system/setup/status'

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['adapter']).to eq('sqlite')
      expect(body['adapters']).to contain_exactly('sqlserver', 'mariadb')
      expect(body['sqlServerConfigured']).to be(false)
      expect(body['setupRequired']).to be(false)
      expect(body['databases']).to eq(%w[productdata users events logs])
      expect(body.to_json).not_to include('password')
    end
  end

  describe 'persistence gate' do
    before { allow(DatabaseSetup::Runtime).to receive(:setup_required?).and_return(true) }

    it 'refuses persistent endpoints while the SQL backend is unconfigured' do
      get '/api/v1/projects'

      expect(response).to have_http_status(:service_unavailable)
      expect(response.parsed_body.dig('error', 'code')).to eq('sql_server_setup_required')
    end

    it 'still serves the setup status' do
      get '/api/v1/system/setup/status'

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['setupRequired']).to be(true)
    end
  end

  describe 'POST /api/v1/system/setup/test' do
    it 'probes connectivity and reports which databases are missing' do
      allow(DatabaseSetup::Connection).to receive(:test!).and_return(
        ok: true, adapter: 'sqlserver', serverVersion: 'Microsoft SQL Server 2022',
        database: 'master', host: 'srv', username: 'u'
      )
      allow(DatabaseSetup::Connection).to receive(:databases).and_return(%w[master productdata])

      post '/api/v1/system/setup/test',
           params: { server: 'srv', username: 'u', password: 'secret' }, as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['ok']).to be(true)
      expect(body['adapter']).to eq('sqlserver')
      expect(body['databases']['existing']).to eq(%w[productdata])
      expect(body['databases']['missing']).to eq(%w[users events logs])
      expect(body.to_json).not_to include('secret')
    end

    it 'accepts a MariaDB adapter and uses its default port' do
      captured = nil
      allow(DatabaseSetup::Connection).to receive(:test!) do |configuration|
        captured = configuration
        { ok: true, adapter: configuration.adapter, serverVersion: 'MariaDB', database: '',
          host: configuration.host, username: configuration.username }
      end
      allow(DatabaseSetup::Connection).to receive(:databases).and_return([])

      post '/api/v1/system/setup/test',
           params: { adapter: 'mariadb', server: 'db', username: 'u', password: 'secret' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(captured.adapter).to eq('mariadb')
      expect(captured.port).to eq(3306)
    end

    it 'is rejected once the SQL backend is already configured' do
      allow(DatabaseSetup::ConfigurationStore).to receive(:configured?).and_return(true)

      post '/api/v1/system/setup/test',
           params: { server: 'srv', username: 'u', password: 'secret' }, as: :json

      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body.dig('error', 'code')).to eq('already_configured')
    end
  end

  describe 'POST /api/v1/system/setup/complete' do
    it 'bootstraps, persists the configuration and returns a redacted summary' do
      allow(DatabaseSetup::Bootstrap).to receive(:call).and_return(
        provisioned: { created: %w[users events logs], existing: %w[productdata] },
        schema: { migrated: 9, pending: 0 },
        imported: { 'users' => 1 },
        seeded: { users: 1, projects: 1, materials: 2 },
        verification: { ok: true, productdata: { ok: true, total_rows: 5 } },
        migration_run: 'run-1'
      )
      allow(DatabaseSetup::ConfigurationStore).to receive(:save)
      allow(DatabaseSetup::Runtime).to receive(:establish_connections!)

      post '/api/v1/system/setup/complete',
           params: { server: 'srv', username: 'u', password: 'secret' }, as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['configured']).to be(true)
      expect(body['adapter']).to eq('sqlserver')
      expect(body['provisioned']['created']).to eq(%w[users events logs])
      expect(body['seeded']).to eq('users' => 1, 'projects' => 1, 'materials' => 2)
      expect(body['verification']['ok']).to be(true)
      expect(body['migrationRun']).to eq('run-1')
      expect(body['configuration']['database']).to eq('productdata')
      expect(body['configuration']['logs_database']).to eq('logs')
      expect(body.to_json).not_to include('secret')
    end

    it 'reports a failed verification with a safe error' do
      allow(DatabaseSetup::Bootstrap).to receive(:call).and_raise(
        DatabaseSetup::Verification::Error, 'migration verification failed (users: missing tables users)'
      )

      post '/api/v1/system/setup/complete',
           params: { server: 'srv', username: 'u', password: 'secret' }, as: :json

      expect(response).to have_http_status(:bad_gateway)
      expect(response.parsed_body.dig('error', 'code')).to eq('migration_verification_failed')
    end

    it 'renders a safe error when the connection fails and redacts the password' do
      allow(DatabaseSetup::Bootstrap).to receive(:call)
        .and_raise(DatabaseSetup::Connection::Error, 'Login failed for secret')

      post '/api/v1/system/setup/complete',
           params: { server: 'srv', username: 'u', password: 'secret' }, as: :json

      expect(response).to have_http_status(:bad_gateway)
      expect(response.parsed_body.dig('error', 'code')).to eq('sql_server_connection_error')
      expect(response.parsed_body.dig('error', 'message')).to include('***')
      expect(response.body).not_to include('secret')
    end
  end
end
