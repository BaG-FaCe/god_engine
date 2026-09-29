# frozen_string_literal: true

module Api
  module V1
    class AuthController < ApplicationController
      # Login is the only pre-authentication endpoint of this controller; the
      # remaining actions (me/logout/…/change_password) require a valid session
      # via the global gate.
      skip_before_action :authenticate_user!, only: :login

      DURATION_MAP = {
        'session' => 86_400,     # 1 day (default for session)
        '1_day' => 86_400,       # 1 day
        '7_days' => 7 * 86_400,  # 7 days
        '30_days' => 30 * 86_400 # 30 days
      }.freeze

      # POST /api/v1/auth/login
      def login
        email = params[:email].to_s.strip.downcase
        password = params[:password].to_s
        user = User.active.find_by(email: email)

        unless user&.authenticate(password)
          # Log failed login attempt without recording password or exposing user existence
          audit('failed_login', auditable: user, metadata: { emailAttempted: email })
          return render_error('E-Mail oder Passwort ist falsch', code: 'invalid_credentials', status: :unauthorized)
        end

        duration_key = params[:duration].to_s
        duration_seconds = DURATION_MAP.fetch(duration_key, 86_400)

        # Issue persistent session token
        session, raw_token = Session.issue!(
          user: user,
          duration: duration_seconds,
          ip: request.remote_ip,
          user_agent: request.user_agent
        )

        user.record_login!
        audit('login', auditable: user, metadata: { duration: duration_key.presence || 'default' })

        render json: {
          token: raw_token,
          session: {
            id: session.id,
            expiresAt: session.expires_at,
            durationSeconds: session.duration_seconds
          },
          user: user.as_json
        }
      end

      # GET /api/v1/auth/me
      def me
        authenticate_user!
        render json: {
          user: current_user.as_json,
          session: current_session&.as_json
        }
      end

      # POST /api/v1/auth/logout
      def logout
        authenticate_user!
        if current_session
          current_session.revoke!(revoked_by: current_user)
          audit('logout', auditable: current_session, metadata: { sessionId: current_session.id })
        end
        render json: { success: true }
      end

      # POST /api/v1/auth/logout_all
      def logout_all
        authenticate_user!
        current_user.revoke_all_sessions!(revoked_by: current_user)
        audit('revoke_all_sessions', auditable: current_user)
        render json: { success: true }
      end

      # POST /api/v1/auth/change_password
      def change_password
        authenticate_user!
        old_password = params[:currentPassword].to_s
        new_password = params[:newPassword].to_s

        unless current_user.authenticate(old_password)
          return render_error('Aktuelles Passwort ist nicht korrekt', code: 'invalid_current_password', status: :unprocessable_entity)
        end

        if new_password.length < 12
          return render_error('Das neue Passwort muss mindestens 12 Zeichen lang sein', code: 'password_too_short', status: :unprocessable_entity)
        end

        current_user.password = new_password
        current_user.save!

        # Invalidate all other sessions for security
        current_user.revoke_all_sessions!(revoked_by: current_user, except_session_id: current_session&.id)
        audit('password_change', auditable: current_user)

        render json: { success: true, message: 'Passwort erfolgreich geändert' }
      end
    end
  end
end

