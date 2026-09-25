require 'rails_helper'

RSpec.describe 'RiskEvents API', type: :request do
  let(:project) { create(:project) }
  let!(:event) { create(:risk_event, project: project, severity: 'critical', title: 'Typhoon') }

  describe 'GET /api/v1/risk_events' do
    it 'lists events' do
      get '/api/v1/risk_events'
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['data'].first['title']).to eq('Typhoon')
    end
  end

  describe 'PATCH /api/v1/risk_events/:id' do
    it 'acknowledges an event' do
      patch "/api/v1/risk_events/#{event.id}", params: { acknowledged: true }.to_json,
                                               headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['acknowledgedAt']).to be_present
      expect(event.reload.acknowledged?).to be(true)
    end
  end
end
