module Api
  module V1
    class MaterialsController < ApplicationController
      before_action :authenticate_user!, except: %i[index show]
      before_action :set_project
      before_action :set_material, only: %i[show update destroy]

      # GET /api/v1/projects/:project_id/materials
      def index
        scope = @project.materials.includes(:supplier, :material_risk_profile, :alternative_suppliers)
                        .ordered.search(params[:q])
        total = scope.count
        pagination = pagination_params
        records = scope.offset((pagination[:page] - 1) * pagination[:per_page]).limit(pagination[:per_page])
        render_paginated(
          records, total: total, page: pagination[:page], per_page: pagination[:per_page],
          serializer: Calculator::Application::MaterialSerializer.method(:call)
        )
      end

      def show
        render json: Calculator::Application::MaterialSerializer.call(@material)
      end

      def create
        require_write!
        material = @project.materials.new(material_params)
        material.save!
        apply_risk_profile(material)
        audit('create', auditable: material, project: @project)
        render json: Calculator::Application::MaterialSerializer.call(material.reload), status: :created
      end

      def update
        require_write!
        @material.update!(material_params)
        apply_risk_profile(@material)
        audit('update', auditable: @material, project: @project)
        render json: Calculator::Application::MaterialSerializer.call(@material.reload)
      end

      def destroy
        require_write!
        audit('delete', auditable: @material, project: @project)
        @material.destroy!
        head :no_content
      end

      # GET /api/v1/projects/:project_id/materials/lead_time_analysis
      def lead_time_analysis
        basis = Calculator::Application::BuildCostBasis.call(project: @project)
        result = Calculator::Domain::LeadTimeAnalyzer.new(basis.materials).call
        render json: result.to_h
      end

      private

      def set_project
        @project = Project.find(params[:project_id])
      end

      def set_material
        @material = @project.materials.find(params[:id])
      end

      def material_params
        params.require(:material).permit(
          :name, :material_type, :supplier_id, :article_number, :description, :image_url,
          :unit, :unit_price_cents, :price_includes_tax, :quantity, :min_order_quantity,
          :lead_time_value, :lead_time_unit, :storage_location, :delivery_address,
          :currency, :stock_quantity, :reorder_level, :position
        )
      end

      def apply_risk_profile(material)
        profile_params = params[:material]&.fetch(:riskProfile, nil)
        return if profile_params.nil?

        permitted = profile_params.permit(
          :origin_country, :hs_code, :shipping_route, :transport_mode, :is_single_source,
          :historical_delay_count, :historical_delay_days, :last_disruption_at,
          :last_disruption_cause, :last_disruption_note, :freight_cost_trend
        ).to_h.symbolize_keys
        profile = material.material_risk_profile || material.build_material_risk_profile
        profile.assign_attributes(permitted)
        profile.save!
      end
    end
  end
end

