require 'rails_helper'

RSpec.describe 'RiskProviders API', type: :request do
  let(:project) { create(:project) }

  describe 'GET /api/v1/risk_providers' do
    it 'lists every catalogue entry with its configuration state' do
      get '/api/v1/risk_providers', params: { projectId: project.id }

      expect(response).to have_http_status(:ok)
      body = response.parsed_body['data']
      expect(body.map { |p| p['key'] }).to include('gdacs', 'heuristic', 'project44')
      expect(body.find { |p| p['key'] == 'gdacs' }['tier']).to eq('free')
    end
  end

  describe 'POST /api/v1/risk_providers/:key/configure' do
    it 'persists a per-project override (enabled + poll interval)' do
      post '/api/v1/risk_providers/gdacs/configure',
           params: { projectId: project.id, enabled: true, pollIntervalMinutes: 45 }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:ok)
      config = RiskProviderConfig.find_by(project: project, provider_key: 'gdacs')
      expect(config.enabled).to be(true)
      expect(config.poll_interval_minutes).to eq(45)
    end

    it 'accepts an encrypted API key and never returns it' do
      post '/api/v1/risk_providers/project44/configure',
           params: { projectId: project.id, apiKey: 'secret-key-12345' }.to_json,
           headers: json_headers

      body = response.parsed_body
      expect(body['apiKeyPresent']).to be(true)
      expect(body['apiKeyHint']).to include('•')
      expect(body['apiKeyHint']).not_to include('secret-key-12345')

      config = RiskProviderConfig.find_by(project: project, provider_key: 'project44')
      expect(config.api_key).to eq('secret-key-12345')
      expect(config.api_key_present?).to be(true)
    end
  end

  describe 'POST /api/v1/risk_providers/:key/probe' do
    it 'returns the documented probe structure for an internal provider' do
      post '/api/v1/risk_providers/heuristic/probe', headers: auth_headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body).to include('ok', 'latencyMs', 'sampleScore', 'message')
    end
  end
end
