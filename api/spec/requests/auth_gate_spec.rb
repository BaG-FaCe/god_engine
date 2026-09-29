# frozen_string_literal: true

require 'rails_helper'

# Regression suite for the *global* authentication gate: the platform is private
# by default. Only the first-run setup, the health probe and the login endpoint
# are reachable without a valid session; everything else fails closed.
RSpec.describe 'Global authentication gate', type: :request do
  let!(:admin) { create(:user, :admin, email: 'admin@god-engine.local', password: 'GodEngine-Admin-123') }
  let!(:viewer) { create(:user, :viewer, email: 'viewer@god-engine.local', password: 'GodEngine-Viewer-123') }

  # A representative sample of protected entry points. The gate is global, so
  # exercising a handful of them is enough to prove the default deny behaviour.
  let(:protected_routes) do
    [
      ['projects', '/api/v1/projects'],
      ['projects#show', "/api/v1/projects/#{SecureRandom.uuid}"],
      ['materials', "/api/v1/projects/#{SecureRandom.uuid}/materials"],
      ['users', '/api/v1/users'],
      ['sessions', '/api/v1/sessions'],
      ['system status', '/api/v1/system/status'],
      ['security events', '/api/v1/security_events'],
      ['jobs', '/api/v1/jobs']
    ]
  end

  describe 'missing token' do
    it 'denies every protected route without a token' do
      protected_routes.each do |label, path|
        get path
        expect(response).to have_http_status(:unauthorized), "expected #{label} (#{path}) to be protected"
      end
    end
  end

  describe 'valid session' do
    it 'allows a protected route with an active session' do
      headers = session_headers(admin)
      get '/api/v1/projects', headers: headers
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'query parameter token (must be ignored)' do
    let(:session_token) { Session.issue!(user: admin).last }

    it 'denies a valid session token passed via ?token= without an Authorization header' do
      get "/api/v1/projects?token=#{session_token}"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'denies an invalid ?token= value' do
      get '/api/v1/projects?token=not-a-valid-session'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'denies a revoked session token passed via ?token=' do
      session, raw_token = Session.issue!(user: admin)
      session.revoke!
      get "/api/v1/projects?token=#{raw_token}"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'does not let a valid ?token= override an invalid Authorization header' do
      get "/api/v1/projects?token=#{session_token}",
          headers: { 'Authorization' => 'Bearer definitely-invalid' }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'does not let query parameters override Authorization-header authentication' do
      get '/api/v1/projects?token=garbage', headers: session_headers(admin)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'invalid / unknown / modified token' do
    it 'denies an unknown token' do
      get '/api/v1/projects', headers: { 'Authorization' => "Bearer #{SecureRandom.hex(32)}" }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'denies a modified token' do
      _session, raw_token = Session.issue!(user: admin)
      tampered = raw_token.chars
      tampered[0] = (tampered[0] == 'a' ? 'b' : 'a')
      get '/api/v1/projects', headers: { 'Authorization' => "Bearer #{tampered.join}" }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'denies a malformed token' do
      get '/api/v1/projects', headers: { 'Authorization' => 'Bearer not-a-token' }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'denies a legacy JWT-shaped token (no second authentication path)' do
      header = Base64.urlsafe_encode64({ alg: 'HS256', typ: 'JWT' }.to_json, padding: false)
      payload = Base64.urlsafe_encode64(
        { sub: admin.id, role: 'admin', exp: 1.hour.from_now.to_i }.to_json, padding: false
      )
      signature = Base64.urlsafe_encode64('forged-signature', padding: false)
      jwt = [header, payload, signature].join('.')

      get '/api/v1/projects', headers: { 'Authorization' => "Bearer #{jwt}" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'expired session' do
    it 'denies an expired session' do
      session, raw_token = Session.issue!(user: admin, duration: 1)
      session.update!(expires_at: 1.minute.ago)

      get '/api/v1/projects', headers: { 'Authorization' => "Bearer #{raw_token}" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'revoked session' do
    it 'denies a revoked session' do
      session, raw_token = Session.issue!(user: admin)
      session.revoke!

      get '/api/v1/projects', headers: { 'Authorization' => "Bearer #{raw_token}" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'disabled user' do
    it 'denies the remembered session of a deactivated user' do
      _session, raw_token = Session.issue!(user: viewer)
      viewer.update!(active: false)

      get '/api/v1/projects', headers: { 'Authorization' => "Bearer #{raw_token}" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'logout' do
    it 'revokes the token so it can no longer be used' do
      _session, raw_token = Session.issue!(user: admin)
      headers = { 'Authorization' => "Bearer #{raw_token}" }

      post '/api/v1/auth/logout', headers: headers
      expect(response).to have_http_status(:ok)

      get '/api/v1/projects', headers: headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'authorization after authentication' do
    it 'still denies admin functionality to an authenticated normal user' do
      %w[/api/v1/users /api/v1/system/status /api/v1/security_events].each do |path|
        get path, headers: session_headers(viewer)
        expect(response).to have_http_status(:forbidden), "expected #{path} to be admin-only"
      end
    end

    it 'allows admin functionality to an authenticated admin' do
      get '/api/v1/users', headers: session_headers(admin)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'pre-authentication surface' do
    it 'keeps health, setup status and login reachable without a session' do
      get '/api/v1/health'
      expect(response).to have_http_status(:ok)

      get '/api/v1/system/setup/status'
      expect(response).to have_http_status(:ok)

      post '/api/v1/auth/login', params: { email: admin.email, password: 'GodEngine-Admin-123' }, as: :json
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'fail closed on validation error' do
    it 'treats a validation failure as unauthenticated' do
      # Simulate the session store raising while validating the token.
      allow(Session).to receive(:authenticate).and_raise(StandardError, 'db unavailable')

      get '/api/v1/projects', headers: session_headers(admin)
      expect(response).not_to have_http_status(:ok)
    end
  end
end
