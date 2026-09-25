# Request-spec helpers.
module RequestHelpers
  # @return [Hash] Authorization header for a user with write access.
  # Deliberately *without* a Content-Type: specs that post JSON bodies merge it
  # in via `json_headers` so form-encoded requests (`params:`) never collide
  # with a JSON Content-Type header.
  def auth_headers(user = nil)
    user ||= create(:user, :admin)
    { 'Authorization' => "Bearer #{Auth::JsonWebToken.encode(user)}",
      'Accept' => 'application/json' }
  end

  def json_headers(user = nil)
    auth_headers(user).merge('Content-Type' => 'application/json')
  end
end

RSpec.configure do |config|
  config.include RequestHelpers, type: :request
end
