# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Authentication & Session API', type: :request do
  let!(:admin) { create(:user, :admin, email: 'admin@god-engine.local', password: 'GodEngine-Admin-123') }
  let!(:viewer) { create(:user, :viewer, email: 'viewer@god-engine.local', password: 'GodEngine-Viewer-123') }
  let!(:disabled_user) { create(:user, :manager, active: false, email: 'disabled@god-engine.local', password: 'GodEngine-Manager-123') }

  describe 'POST /api/v1/auth/login' do
    it 'authenticates active user with correct password and returns persistent session token' do
      post '/api/v1/auth/login', params: {
        email: 'admin@god-engine.local',
        password: 'GodEngine-Admin-123',
        duration: '7_days'
      }, as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['token']).to be_present
      expect(body.dig('session', 'id')).to be_present
      expect(body.dig('user', 'email')).to eq('admin@god-engine.local')

      # Token hash in DB matches raw token
      session_id = body.dig('session', 'id')
      db_session = Session.find(session_id)
      expect(db_session.token_hash).to eq(Digest::SHA256.hexdigest(body['token']))
      expect(db_session.duration_seconds).to eq(7 * 86_400)
    end

    it 'fails on incorrect password with generic safe message and audits failed attempt' do
      expect do
        post '/api/v1/auth/login', params: {
          email: 'admin@god-engine.local',
          password: 'WrongPassword123!'
        }, as: :json
      end.to change(AuditLog, :count).by(1)

      expect(response).to have_http_status(:unauthorized)
      body = response.parsed_body
      expect(body.dig('error', 'code')).to eq('invalid_credentials')
      expect(body.dig('error', 'message')).to eq('E-Mail oder Passwort ist falsch')

      log = AuditLog.last
      expect(log.action).to eq('failed_login')
    end

    it 'fails for unknown email without disclosing existence' do
      post '/api/v1/auth/login', params: {
        email: 'nobody@nowhere.com',
        password: 'SomePassword123!'
      }, as: :json

      expect(response).to have_http_status(:unauthorized)
      body = response.parsed_body
      expect(body.dig('error', 'code')).to eq('invalid_credentials')
    end

    it 'fails for disabled user' do
      post '/api/v1/auth/login', params: {
        email: 'disabled@god-engine.local',
        password: 'GodEngine-Manager-123'
      }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/auth/me' do
    it 'validates active persistent session' do
      headers = session_headers(admin)
      get '/api/v1/auth/me', headers: headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.dig('user', 'email')).to eq(admin.email)
      expect(body.dig('session', 'id')).to be_present
    end

    it 'rejects expired session' do
      session, raw_token = Session.issue!(user: admin, duration: 1)
      session.update!(expires_at: 1.minute.ago)

      get '/api/v1/auth/me', headers: { 'Authorization' => "Bearer #{raw_token}" }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects revoked session' do
      session, raw_token = Session.issue!(user: admin)
      session.revoke!

      get '/api/v1/auth/me', headers: { 'Authorization' => "Bearer #{raw_token}" }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects session when user is deactivated' do
      _session, raw_token = Session.issue!(user: admin)
      admin.update!(active: false)

      get '/api/v1/auth/me', headers: { 'Authorization' => "Bearer #{raw_token}" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/auth/logout' do
    it 'revokes the active session' do
      session, raw_token = Session.issue!(user: admin)
      expect(session.active?).to be(true)

      post '/api/v1/auth/logout', headers: { 'Authorization' => "Bearer #{raw_token}" }
      expect(response).to have_http_status(:ok)

      expect(session.reload.revoked?).to be(true)

      # Subsequent request with same token fails
      get '/api/v1/auth/me', headers: { 'Authorization' => "Bearer #{raw_token}" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/auth/logout_all' do
    it 'revokes all active sessions for current user' do
      session1, _t1 = Session.issue!(user: admin)
      session2, _t2 = Session.issue!(user: admin)
      _session_viewer, _tv = Session.issue!(user: viewer)

      headers = session_headers(admin)
      post '/api/v1/auth/logout_all', headers: headers

      expect(response).to have_http_status(:ok)
      expect(session1.reload.revoked?).to be(true)
      expect(session2.reload.revoked?).to be(true)
      expect(_session_viewer.reload.revoked?).to be(false)
    end
  end

  describe 'POST /api/v1/auth/change_password' do
    it 'changes password, requires valid old password and revokes other sessions' do
      s1, _t1 = Session.issue!(user: admin)
      _s2, t2 = Session.issue!(user: admin)

      post '/api/v1/auth/change_password', params: {
        currentPassword: 'GodEngine-Admin-123',
        newPassword: 'BrandNewSecretPass123!'
      }, headers: { 'Authorization' => "Bearer #{t2}", 'Content-Type' => 'application/json' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(admin.reload.authenticate('BrandNewSecretPass123!')).to be_truthy

      # Other session s1 is revoked
      expect(s1.reload.revoked?).to be(true)
      # Current session remains active
      expect(_s2.reload.active?).to be(true)
    end
  end
end
