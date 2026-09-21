module Api
  module V1
    # Material risk endpoints (spec § API-Design REST).
    class MaterialRiskController < ApplicationController
      before_action :authenticate_user!, except: %i[show events]
      before_action :set_material

      # GET /api/v1/materials/:id/risk_assessment
      def show
        render json: SupplyChainRisk::Application::AggregateProductRisk.material_view(@material)
      end

      # GET /api/v1/materials/:id/risk_events
      def events
        events = @material.risk_events.recent.limit(50)
        render json: { data: events.map { |e| event_json(e) } }
      end

      # POST /api/v1/materials/:id/risk_assessment/manual
      def create_manual
        require_write!
        level = params.require(:level)
        profile = @material.material_risk_profile || @material.build_material_risk_profile
        profile.record_manual_assessment!(
          level: level, note: params[:note], user: current_user, score: params[:score]
        )
        draft = SupplyChainRisk::Infrastructure::Providers::Internal::ManualProvider.new.assess(
          SupplyChainRisk::Domain::Subject.from_material(@material.reload)
        )
        if draft
          assessment = RiskAssessment.create!(
            draft.to_assessment_attributes(material_id: @material.id).merge(origin: 'manual')
          )
          @material.update_columns(
            risk_score: assessment.risk_score, risk_level: assessment.risk_level,
            last_risk_checked_at: assessment.fetched_at, updated_at: Time.current
          )
        end
        audit('update', auditable: @material, project: @material.project,
                         metadata: { manualLevel: level })
        render json: SupplyChainRisk::Application::AggregateProductRisk.material_view(@material.reload)
      end

      # POST /api/v1/materials/:id/risk_assessment/refresh
      def refresh
        require_write!
        job = SupplyChainRisk::RefreshMaterialRiskJob.perform_later(@material.id)
        audit('refresh', auditable: @material, project: @material.project)
        render json: {
          materialId: @material.id, jobId: job.job_id, queued: true,
          providerKeys: [], message: 'Risiko-Aktualisierung gestartet'
        }, status: :accepted
      end

      private

      def set_material
        @material = Material.find(params[:id])
      end

      def event_json(event)
        { id: event.id, materialId: event.material_id, eventType: event.event_type,
          severity: event.severity, title: event.title, description: event.description,
          source: event.source, occurredAt: event.occurred_at&.iso8601,
          acknowledgedAt: event.acknowledged_at&.iso8601 }
      end
    end
  end
end
