require 'rails_helper'

RSpec.describe 'RiskNotifications API', type: :request do
  let(:project) { create(:project) }
  let!(:open) { create(:risk_notification, project: project, title: 'offen') }
  let!(:dismissed) { create(:risk_notification, :dismissed, project: project, title: 'verworfen') }

  describe 'GET /api/v1/risk_notifications' do
    it 'lists only open notifications by default and returns the counts' do
      get '/api/v1/risk_notifications', params: { projectId: project.id }

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['data'].map { |n| n['title'] }).to include('offen')
      expect(body['data'].map { |n| n['title'] }).not_to include('verworfen')
      expect(body.dig('meta', 'openCount')).to eq(1)
      expect(body.dig('meta', 'dismissedCount')).to eq(1)
    end

    it 'returns the dismissed ones when status=dismissed is requested' do
      get '/api/v1/risk_notifications', params: { projectId: project.id, status: 'dismissed' }

      expect(response.parsed_body['data'].map { |n| n['title'] }).to include('verworfen')
    end
  end

  describe 'POST /api/v1/risk_notifications/:id/acknowledge' do
    it 'marks the notification as acknowledged and keeps it in the history' do
      post "/api/v1/risk_notifications/#{open.id}/acknowledge", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('notification', 'status')).to eq('acknowledged')
      expect(open.reload.acknowledged?).to be(true)
      expect(RiskNotification.find(open.id)).to be_present # never deleted
    end

    it 'requires write access' do
      post "/api/v1/risk_notifications/#{open.id}/acknowledge",
           headers: auth_headers(create(:user, :viewer))

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /api/v1/risk_notifications/:id/dismiss' do
    it 'marks the notification as dismissed without deleting it' do
      post "/api/v1/risk_notifications/#{open.id}/dismiss", headers: auth_headers

      expect(response.parsed_body.dig('notification', 'status')).to eq('dismissed')
      expect(RiskNotification.find(open.id)).to be_present
    end
  end

  describe 'POST /api/v1/risk_notifications/read_all' do
    it 'marks every open notification read for the scope' do
      post '/api/v1/risk_notifications/read_all',
           params: { projectId: project.id }, headers: auth_headers

      expect(response.parsed_body['updated']).to eq(1)
      expect(open.reload.read?).to be(true)
    end
  end

  describe 'the /api/v1/notifications alias' do
    it 'routes the same controller for index and acknowledge' do
      get '/api/v1/notifications', params: { projectId: project.id }
      expect(response).to have_http_status(:ok)

      post "/api/v1/notifications/#{open.id}/acknowledge", headers: auth_headers
      expect(response).to have_http_status(:ok)
    end
  end
end
