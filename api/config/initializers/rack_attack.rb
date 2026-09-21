# Inbound rate limiting and brute-force protection for the JSON API.
#
# This is the *inbound* counterpart of
# `Shared::Infrastructure::Http::RateLimiter`, which protects the *outbound*
# calls to the external risk data providers.
class RackAttackConfig
  LOGIN_LIMIT = 10
  LOGIN_PERIOD = 60
  API_LIMIT = 600
  API_PERIOD = 300

  def self.install!
    Rack::Attack.cache.store = Rails.cache

    # Health checks must never be throttled.
    Rack::Attack.safelist('health check') do |req|
      req.path == '/up' || req.path == '/api/v1/health'
    end

    # Credential stuffing protection for the login endpoint.
    Rack::Attack.throttle('logins/ip', limit: LOGIN_LIMIT, period: LOGIN_PERIOD) do |req|
      req.ip if req.path == '/api/v1/auth/login' && req.post?
    end

    Rack::Attack.throttle('logins/email', limit: LOGIN_LIMIT, period: LOGIN_PERIOD) do |req|
      if req.path == '/api/v1/auth/login' && req.post?
        req.params['email'].to_s.downcase.presence
      end
    end

    # General API quota, per bearer token when present, otherwise per IP.
    Rack::Attack.throttle('api/token', limit: API_LIMIT, period: API_PERIOD) do |req|
      next unless req.path.start_with?('/api/')

      auth = req.env['HTTP_AUTHORIZATION'].to_s
      auth.start_with?('Bearer ') ? Digest::SHA256.hexdigest(auth) : nil
    end

    Rack::Attack.throttle('api/ip', limit: API_LIMIT, period: API_PERIOD) do |req|
      req.ip if req.path.start_with?('/api/')
    end

    Rack::Attack.blocklist('blocked ips') do |req|
      ENV.fetch('BLOCKED_IPS', '').split(',').map(&:strip).reject(&:empty?).include?(req.ip)
    end

    Rack::Attack.throttled_responder = lambda do |request|
      match_data = request.env['rack.attack.match_data'] || {}
      headers = {
        'Content-Type' => 'application/json',
        'Retry-After' => (match_data[:period] || 60).to_s,
        'X-RateLimit-Limit' => (match_data[:limit] || API_LIMIT).to_s,
        'X-RateLimit-Remaining' => '0',
      }
      body = {
        error: {
          code: 'rate_limited',
          message: 'Zu viele Anfragen. Bitte versuchen Sie es später erneut.',
        },
      }
      [429, headers, [body.to_json]]
    end
  end
end

Rails.application.config.after_initialize do
  RackAttackConfig.install!
end
