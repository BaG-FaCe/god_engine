# frozen_string_literal: true

module Api
  module V1
    # Read-only security event audit log view for administrators.
    class SecurityEventsController < ApplicationController
      before_action :authenticate_user!
      before_action :require_admin!

      SECURITY_ACTIONS = %w[
        login failed_login logout revoke_session revoke_all_sessions
        password_change user_create user_update user_disable user_enable configure
      ].freeze

      # GET /api/v1/security_events
      def index
        scope = AuditLog.where(action: SECURITY_ACTIONS).recent.limit(150)
        scope = scope.where(action: params[:actionFilter]) if params[:actionFilter].present?

        events = scope.map do |log|
          {
            id: log.id,
            action: log.action,
            userName: log.user_name,
            userId: log.user_id,
            ip: log.ip,
            userAgent: log.user_agent,
            occurredAt: log.occurred_at,
            metadata: log.changeset
          }
        end

        render json: { data: events }
      end
    end
  end
end
