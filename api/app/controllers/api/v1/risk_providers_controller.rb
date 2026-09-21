module Api
  module V1
    class RiskProvidersController < ApplicationController
      before_action :authenticate_user!, except: %i[index]

      # GET /api/v1/risk_providers?projectId=
      def index
        project = Project.find_by(id: params[:projectId])
        render json: {
          data: SupplyChainRisk::Infrastructure::ProviderRegistry.statuses(project)
        }
      end

      # POST /api/v1/risk_providers/:key/configure
      def configure
        require_write!
        descriptor = SupplyChainRisk::Infrastructure::ProviderRegistry.find!(params[:key])
        project = params[:projectId].present? ? Project.find(params[:projectId]) : nil
        config = RiskProviderConfig.find_or_initialize_by(
          project_id: project&.id, provider_key: descriptor.key
        )
        config.enabled = params[:enabled] unless params[:enabled].nil?
        config.poll_interval_minutes = params[:pollIntervalMinutes] if params[:pollIntervalMinutes]
        config.priority = params[:priority] if params[:priority]
        config.config = params[:config].to_h if params[:config]
        config.api_key = params[:apiKey] if params[:apiKey].present?
        config.save!
        audit('configure', project: project, metadata: { providerKey: descriptor.key })
        render json: { providerKey: descriptor.key, apiKeyPresent: config.api_key_present?,
                       apiKeyHint: config.api_key_hint, enabled: config.enabled }
      end

      # POST /api/v1/risk_providers/:key/probe
      def probe
        descriptor = SupplyChainRisk::Infrastructure::ProviderRegistry.find!(params[:key])
        provider = SupplyChainRisk::Infrastructure::ProviderRegistry.resolve(params[:key])
        result = provider.probe
        render json: { providerKey: descriptor.key, ok: result[:ok],
                       latencyMs: result[:latencyMs], sampleScore: result[:sampleScore],
                       message: result[:message] }
      end
    end
  end
end
