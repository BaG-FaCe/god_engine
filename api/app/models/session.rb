# frozen_string_literal: true

require 'digest'
require 'securerandom'

# Persistent authenticated session (stored in the `users` database of a SQL backend).
#
# Tokens are never stored as plaintext in the database:
# Raw secret (hex, 32 bytes) is delivered once to the client.
# The database only stores `token_hash = Digest::SHA256.hexdigest(raw_token)`.
class Session < UsersRecord
  belongs_to :user
  belongs_to :revoked_by, class_name: 'User', optional: true

  validates :user_id, presence: true
  validates :token_hash, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :duration_seconds, presence: true, numericality: { greater_than: 0 }

  scope :active, -> { where(revoked_at: nil).where('expires_at > ?', Time.current) }
  scope :unexpired, -> { where('expires_at > ?', Time.current) }
  scope :revoked, -> { where.not(revoked_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  class << self
    # Creates a new persistent session for a user.
    # Returns [session_record, raw_token_string]
    def issue!(user:, duration: 86_400, ip: nil, user_agent: nil)
      raw_token = SecureRandom.hex(32)
      token_hash = Digest::SHA256.hexdigest(raw_token)
      expires_at = Time.current + duration.seconds

      session = create!(
        user: user,
        token_hash: token_hash,
        duration_seconds: duration,
        expires_at: expires_at,
        last_activity_at: Time.current,
        ip: ip,
        user_agent: user_agent.to_s.truncate(255)
      )

      [session, raw_token]
    end

    # Validates a raw token presented by a client.
    # Returns the Session instance if active and user is active, nil otherwise.
    def authenticate(raw_token)
      return nil if raw_token.blank?

      token_hash = Digest::SHA256.hexdigest(raw_token.to_s.strip)
      session = active.includes(:user).find_by(token_hash: token_hash)
      return nil unless session
      return nil unless session.user&.active?

      session.touch_activity!
      session
    end
  end

  def active?
    revoked_at.nil? && expires_at > Time.current
  end

  def expired?
    expires_at <= Time.current
  end

  def revoked?
    revoked_at.present?
  end

  def revoke!(revoked_by: nil)
    return if revoked?

    update!(
      revoked_at: Time.current,
      revoked_by: revoked_by
    )
  end

  def touch_activity!
    # Throttled update to avoid excessive DB writes
    return if last_activity_at > 5.minutes.ago

    update_column(:last_activity_at, Time.current)
  end

  def as_json(*)
    {
      id: id,
      userId: user_id,
      userName: user&.name,
      userEmail: user&.email,
      ip: ip,
      userAgent: user_agent,
      durationSeconds: duration_seconds,
      expiresAt: expires_at,
      revokedAt: revoked_at,
      revokedById: revoked_by_id,
      lastActivityAt: last_activity_at,
      createdAt: created_at,
      active: active?
    }
  end
end
