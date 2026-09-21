module Api
  module V1
    class RiskSummariesController < ApplicationController
      before_action :set_project

      # GET /api/v1/projects/:project_id/risk_summary
      def show
        aggregate = SupplyChainRisk::Application::AggregateProductRisk.call(project: @project)
        material_ids = @project.materials.pluck(:id)
        distribution = @project.materials.group(:risk_level).count
        render json: {
          projectId: @project.id,
          materialCount: aggregate[:materialCount],
          averageRiskScore: aggregate[:aggregateScore],
          criticalCount: aggregate[:criticalMaterialCount],
          elevatedCount: distribution['medium'] || 0,
          lowCount: distribution['low'] || 0,
          unknownCount: @project.materials.where(risk_score: nil).count,
          distribution: distribution.map { |level, count| { level: level || 'unknown', count: count } },
          timeline: RiskScoreSnapshot.daily_average(material_ids),
          criticalMaterials: @project.materials.critical_risk.limit(10).map do |material|
            { materialId: material.id, name: material.name, riskScore: material.risk_score,
              riskLevel: material.risk_level,
              originCountry: material.material_risk_profile&.origin_country,
              lastCheckedAt: material.last_risk_checked_at&.iso8601 }
          end,
          recentEvents: @project.risk_events.recent.limit(10).map do |event|
            { id: event.id, title: event.title, severity: event.severity,
              eventType: event.event_type, source: event.source,
              occurredAt: event.occurred_at&.iso8601 }
          end
        }
      end

      private

      def set_project
        @project = Project.find(params[:project_id])
      end
    end
  end
end
