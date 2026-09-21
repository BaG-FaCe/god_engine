module Api
  module V1
    class RiskEventsController < ApplicationController
      before_action :set_project, only: %i[index]

      # GET /api/v1/risk_events + nested GET /api/v1/projects/:project_id/risk_events
      def index
        scope = @project ? @project.risk_events : RiskEvent.all
        scope = scope.where(severity: params[:severity]) if params[:severity].present?
        scope = scope.where(event_type: params[:eventType]) if params[:eventType].present?
        scope = scope.unacknowledged if params[:unacknowledged] == 'true'
        scope = scope.recent.limit(100)
        render json: { data: scope.map { |event| event_json(event) } }
      end

      def show
        render json: event_json(RiskEvent.find(params[:id]))
      end

      # PATCH /api/v1/risk_events/:id (acknowledge)
      def update
        require_write!
        event = RiskEvent.find(params[:id])
        event.acknowledge!(current_user) if params[:acknowledged] != false
        render json: event_json(event)
      end

      private

      def set_project
        @project = Project.find(params[:project_id]) if params[:project_id].present?
      end

      def event_json(event)
        { id: event.id, materialId: event.material_id, projectId: event.project_id,
          countryCode: event.country_code, eventType: event.event_type,
          severity: event.severity, title: event.title, description: event.description,
          source: event.source, sourceEventId: event.source_event_id,
          occurredAt: event.occurred_at&.iso8601,
          acknowledgedAt: event.acknowledged_at&.iso8601, metadata: event.metadata }
      end
    end
  end
end
