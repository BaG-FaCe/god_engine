# Request-spec helpers.
module RequestHelpers
  # @return [Hash] Authorization header for a user with write access.
  # Uses a real SQL-backed Session (via `Session.issue!`) so tests exercise the
  # same authoritative authentication path as the application itself.
  # Deliberately *without* a Content-Type: specs that post JSON bodies merge it
  # in via `json_headers` so form-encoded requests (`params:`) never collide
  # with a JSON Content-Type header.
  def auth_headers(user = nil)
    session_headers(user)
  end

  def session_headers(user = nil, duration: 86_400)
    user ||= create(:user, :admin)
    _session, raw_token = Session.issue!(user: user, duration: duration)
    { 'Authorization' => "Bearer #{raw_token}",
      'Accept' => 'application/json' }
  end

  def json_headers(user = nil)
    auth_headers(user).merge('Content-Type' => 'application/json')
  end

  def session_json_headers(user = nil, duration: 86_400)
    session_headers(user, duration: duration).merge('Content-Type' => 'application/json')
  end
end

RSpec.configure do |config|
  config.include RequestHelpers, type: :request
end

