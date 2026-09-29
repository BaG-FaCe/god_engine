# frozen_string_literal: true

module Api
  module V1
    # Admin-only user management backed by SQL Server `users` database.
    class UsersController < ApplicationController
      before_action :authenticate_user!
      before_action :require_admin!
      before_action :set_user, only: %i[show update destroy reset_password]

      # GET /api/v1/users
      def index
        scope = User.all
        if params[:q].present?
          query = "%#{params[:q].to_s.strip.downcase}%"
          scope = scope.where('LOWER(name) LIKE ? OR LOWER(email) LIKE ?', query, query)
        end
        scope = scope.where(role: params[:role]) if params[:role].present?
        scope = scope.where(active: params[:active] == 'true') if params[:active].present?

        users = scope.order(:name)
        render json: { data: users.map(&:as_json) }
      end

      # GET /api/v1/users/:id
      def show
        render json: { user: @user.as_json }
      end

      # POST /api/v1/users
      def create
        user = User.new(user_params)
        user.password = params[:password].presence || SecureRandom.alphanumeric(16)
        user.save!

        audit('user_create', auditable: user, metadata: { role: user.role, email: user.email })
        render json: { user: user.as_json }, status: :created
      end

      # PATCH /api/v1/users/:id
      def update
        # Guard against self-lockout or removing the last admin
        if updating_self?
          if user_params[:active] == false || user_params[:active] == 'false'
            return render_error('Sie können Ihr eigenes Konto nicht deaktivieren', code: 'cannot_disable_self', status: :unprocessable_entity)
          end
          if user_params[:role].present? && user_params[:role] != 'admin'
            return render_error('Sie können Ihre eigene Administrator-Rolle nicht entfernen', code: 'cannot_demote_self', status: :unprocessable_entity)
          end
        end

        if @user.admin? && user_params[:role].present? && user_params[:role] != 'admin' && User.last_admin?(@user.id)
          return render_error('Der letzte aktive Administrator kann nicht herabgestuft werden', code: 'last_admin', status: :unprocessable_entity)
        end

        if @user.admin? && (user_params[:active] == false || user_params[:active] == 'false') && User.last_admin?(@user.id)
          return render_error('Der letzte aktive Administrator kann nicht deaktiviert werden', code: 'last_admin', status: :unprocessable_entity)
        end

        old_active = @user.active
        @user.update!(user_params)

        if old_active != @user.active
          action = @user.active ? 'user_enable' : 'user_disable'
          audit(action, auditable: @user)
          # If disabled, revoke all sessions immediately!
          @user.revoke_all_sessions!(revoked_by: current_user) unless @user.active
        else
          audit('user_update', auditable: @user)
        end

        render json: { user: @user.as_json }
      end

      # POST /api/v1/users/:id/reset_password
      def reset_password
        new_password = params[:newPassword].to_s
        if new_password.length < 12
          return render_error('Das Passwort muss mindestens 12 Zeichen lang sein', code: 'password_too_short', status: :unprocessable_entity)
        end

        @user.password = new_password
        @user.save!

        # Revoke all existing sessions for this user so they must log in with new credentials
        @user.revoke_all_sessions!(revoked_by: current_user)
        audit('password_change', auditable: @user, metadata: { resetByAdmin: true })

        render json: { success: true, message: 'Passwort erfolgreich zurückgesetzt' }
      end

      private

      def set_user
        @user = User.find(params[:id])
      end

      def updating_self?
        @user.id == current_user.id
      end

      def user_params
        params.require(:user).permit(:name, :email, :role, :active, :locale)
      end
    end
  end
end
