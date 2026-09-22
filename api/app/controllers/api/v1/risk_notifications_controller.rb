module Api
  module V1
    # In-app risk notifications (spec § Lieferrisiko-Management):
    # "Bei 🔴 oder neuem risk_event wird eine In-App-Benachrichtigung ausgelöst".
    class RiskNotificationsController < ApplicationController
      before_action :set_notification, only: %i[show update]

      # GET /api/v1/risk_notifications?projectId=&unread=true
      def index
        scope = project_scoped
        scope = scope.unread if params[:unread] == 'true'
        scope = scope.recent.limit(50)
        render json: {
          data: scope.map { |notification| notification_json(notification) },
          meta: { unreadCount: project_scoped.unread.count }
        }
      end

      def show
        render json: notification_json(@notification)
      end

      # PATCH /api/v1/risk_notifications/:id { read: true }
      def update
        require_write!
        @notification.mark_read!(user: current_user) if params[:read] != false
        render json: notification_json(@notification)
      end

      private

      def project_scoped
        project = Project.find_by(id: params[:projectId])
        project ? RiskNotification.for_project(project) : RiskNotification.all
      end

      def set_notification
        @notification = RiskNotification.find(params[:id])
      end

      def notification_json(notification)
        { id: notification.id, projectId: notification.project_id,
          materialId: notification.material_id, riskEventId: notification.risk_event_id,
          kind: notification.kind, severity: notification.severity,
          title: notification.title, body: notification.body,
          payload: notification.payload, readAt: notification.read_at&.iso8601,
          createdAt: notification.created_at&.iso8601 }
      end
    end
  end
end
