# frozen_string_literal: true

module Api
  module V1
    # Admin session inspection and revocation.
    class SessionsController < ApplicationController
      before_action :authenticate_user!
      before_action :require_admin!, only: %i[index revoke_user]

      # GET /api/v1/sessions - Admin: all sessions; Normal user: own sessions
      def index
        scope = current_user.admin? ? Session.all : current_user.sessions
        scope = scope.where(user_id: params[:userId]) if params[:userId].present? && current_user.admin?
        scope = scope.active if params[:active] == 'true'

        sessions = scope.includes(:user).recent.limit(100)
        render json: { data: sessions.map(&:as_json) }
      end

      # DELETE /api/v1/sessions/:id
      def destroy
        session = Session.find(params[:id])
        # Only admin or the session owner can revoke
        unless current_user.admin? || session.user_id == current_user.id
          raise Forbidden
        end

        session.revoke!(revoked_by: current_user)
        audit('revoke_session', auditable: session, metadata: { targetUserId: session.user_id })

        render json: { success: true }
      end

      # POST /api/v1/sessions/revoke_user (Admin only)
      def revoke_user
        target_user = User.find(params[:userId])
        target_user.revoke_all_sessions!(revoked_by: current_user)
        audit('revoke_all_sessions', auditable: target_user, metadata: { adminAction: true })

        render json: { success: true }
      end
    end
  end
end
