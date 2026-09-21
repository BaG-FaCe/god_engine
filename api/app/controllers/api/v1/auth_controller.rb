module Api
  module V1
    class AuthController < ApplicationController
      # POST /api/v1/auth/login
      def login
        user = User.active.find_by(email: params[:email].to_s.strip.downcase)
        unless user&.authenticate(params[:password].to_s)
          return render_error('E-Mail oder Passwort ist falsch', code: 'invalid_credentials', status: :unauthorized)
        end

        user.record_login!
        audit('login', auditable: user)
        render json: { token: Auth::JsonWebToken.encode(user), user: user.as_json }
      end

      # GET /api/v1/auth/me
      def me
        authenticate_user!
        render json: { user: current_user.as_json }
      end
    end
  end
end
