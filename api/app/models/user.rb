# Platform user (stored in the `users` database of a SQL backend).
# Roles are intentionally coarse - fine grained permissions can be
# layered on later without touching the domain modules.
class User < UsersRecord
  ROLES = %w[admin manager viewer].freeze

  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :audit_logs, dependent: :nullify
  has_many :owned_projects, class_name: 'Project', foreign_key: :owner_id,
                            dependent: :nullify, inverse_of: :owner

  normalizes :email, with: ->(value) { value.strip.downcase }

  validates :name, presence: true, length: { maximum: 120 }
  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, presence: true, inclusion: { in: ROLES }
  validates :password, length: { minimum: 12 }, allow_nil: true,
                       if: -> { password_digest_changed? || new_record? }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }

  def admin?
    role == 'admin'
  end

  def can_write?
    %w[admin manager].include?(role)
  end

  def record_login!
    update_column(:last_login_at, Time.current)
  end

  def revoke_all_sessions!(revoked_by: nil, except_session_id: nil)
    scope = sessions.active
    scope = scope.where.not(id: except_session_id) if except_session_id.present?
    scope.find_each { |s| s.revoke!(revoked_by: revoked_by) }
  end

  # Safeguards against admin self-lockout or removing the last admin.
  def self.last_admin?(user_id)
    where(role: 'admin', active: true).where.not(id: user_id).empty?
  end

  def as_json(*)
    {
      id: id,
      email: email,
      name: name,
      role: role,
      active: active,
      lastLoginAt: last_login_at
    }
  end
end