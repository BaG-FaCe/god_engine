module Auth
  # JWT issuance / verification (HS256, 24h expiry by default).
  module JsonWebToken
    ALGORITHM = 'HS256'.freeze
    DEFAULT_TTL = 24.hours.freeze

    class << self
      def encode(user, ttl: DEFAULT_TTL)
        payload = {
          sub: user.id, email: user.email, role: user.role,
          iat: Time.current.to_i, exp: (Time.current + ttl).to_i
        }
        JWT.encode(payload, secret, ALGORITHM)
      end

      def decode(token)
        decoded = JWT.decode(token, secret, true, algorithm: ALGORITHM)
        decoded.first
      end

      def secret
        ENV['JWT_SECRET'].presence ||
          Rails.application.credentials.jwt_secret.presence ||
          Rails.application.key_generator.generate_key('jwt', 64)
      end
    end
  end
end
