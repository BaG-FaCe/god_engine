module Api
  module V1
    # In-app risk notifications (spec § Lieferrisiko: "Bei 🔴 oder neuem risk_event wird eine In-App-Benachrichtigung ausgelöst").
    #
    # Lifecycle:
    #   * created by `NotifyRiskAlert` (never deleted)
    #   * read by the current user (marker "angezeigt", zählt nicht mehr als ungelesen)
    #   * acknowledged by the current user (marker "gesehen", bleibt in Historie)
    #   * dismissed by the current user (verworfen, aber nicht gelöscht, damit Audit-Historie erhalten bleibt)
    #
    # Exposed under `/api/v1/risk_notifications` and the shorter alias
    # `/api/v1/notifications` (see config/routes.rb).
    class RiskNotificationsController < ApplicationController
      before_action :set_notification, only: %i[show acknowledge dismiss read]

      STATUSES = %w[open unread acknowledged dismissed all].freeze

      # GET /api/v1/risk_notifications?projectId=&status=&severity=
      def index
        scope = filtered_scope
        render json: {
          data: scope.recent.limit(limit).map { |notification| notification_json(notification) },
          meta: meta_for
        }
      end

      def show
        @notification.mark_read!(user: current_user) if current_user
        render json: notification_json(@notification)
      end

      # POST /api/v1/risk_notifications/:id/acknowledge
      def acknowledge
        require_write!
        @notification.acknowledge!(current_user)
        render json: { notification: notification_json(@notification), meta: meta_for }
      end

      # POST /api/v1/risk_notifications/:id/dismiss
      def dismiss
        require_write!
        @notification.dismiss!(current_user)
        render json: { notification: notification_json(@notification), meta: meta_for }
      end

      # PATCH /api/v1/risk_notifications/:id/read
      def read
        require_write!
        @notification.mark_read!(user: current_user)
        render json: { notification: notification_json(@notification), meta: meta_for }
      end

      # POST /api/v1/risk_notifications/read_all
      def read_all
        require_write!
        updated = filtered_scope.where(read_at: nil).update_all(read_at: Time.current,
                                                               read_by_id: current_user.id,
                                                               updated_at: Time.current)
        render json: { updated: updated, meta: meta_for }
      end

      private

      def project_scope
        project = Project.find_by(id: params[:projectId])
        project ? RiskNotification.for_project(project) : RiskNotification.all
      end

      def filtered_scope
        scope = project_scope
        scope = scope.where(severity: params[:severity]) if params[:severity].present?
        apply_status(scope)
      end

      def apply_status(scope)
        case params[:status].presence || (params[:unread] == 'true' ? 'unread' : 'open')
        when 'unread' then scope.unread
        when 'acknowledged' then scope.where.not(acknowledged_at: nil)
        when 'dismissed' then scope.where.not(dismissed_at: nil)
        when 'all' then scope
        else scope.undismissed
        end
      end

      def limit
        value = params[:limit].to_i
        value.positive? ? [value, 200].min : 50
      end

      def meta_for
        scope = project_scope
        {
          unreadCount: scope.undismissed.unread.count,
          openCount: scope.undismissed.count,
          acknowledgedCount: scope.where.not(acknowledged_at: nil).count,
          dismissedCount: scope.where.not(dismissed_at: nil).count
        }
      end

      def set_notification
        @notification = RiskNotification.find(params[:id])
      end

      def notification_json(notification)
        {
          id: notification.id,
          projectId: notification.project_id,
          materialId: notification.material_id,
          riskEventId: notification.risk_event_id,
          kind: notification.kind,
          severity: notification.severity,
          title: notification.title,
          body: notification.body,
          payload: notification.payload,
          status: notification.status,
          readAt: notification.read_at&.iso8601,
          acknowledgedAt: notification.acknowledged_at&.iso8601,
          acknowledgedBy: notification.acknowledged_by_id,
          dismissedAt: notification.dismissed_at&.iso8601,
          dismissedBy: notification.dismissed_by_id,
          createdAt: notification.created_at&.iso8601
        }
      end
    end
  end
end

