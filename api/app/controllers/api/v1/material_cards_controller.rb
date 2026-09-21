module Api
  module V1
    class MaterialCardsController < ApplicationController
      before_action :set_material

      # GET /api/v1/materials/:id/card — full material card incl. risk traffic light.
      def show
        risk_view = SupplyChainRisk::Application::AggregateProductRisk.material_view(@material)
        buffer = { 'high' => 14, 'medium' => 7, 'low' => 2 }.fetch(@material.risk_level.to_s, 0)
        render json: {
          material: Calculator::Application::MaterialSerializer.call(@material),
          supplier: @material.supplier && Calculator::Application::Serializers.supplier(@material.supplier),
          logistics: {
            leadTimeDays: @material.lead_time_days,
            plannedLeadTimeDays: @material.lead_time_days,
            actualLeadTimeDays: nil,
            leadTimeVarianceDays: @material.latest_risk_assessment&.lead_time_variance_days,
            riskWeightedLeadTimeDays: @material.lead_time_days + buffer,
            deliveryAddress: @material.delivery_address
          },
          purchasing: {
            unitPriceNetCents: @material.net_unit_price_cents,
            unitPriceGrossCents: @material.gross_unit_price_cents,
            minOrderQuantity: @material.min_order_quantity.to_f,
            totalValueNetCents: @material.total_value_net_cents
          },
          stock: {
            stockQuantity: @material.stock_quantity.to_f,
            reorderLevel: @material.reorder_level.to_f,
            belowReorderLevel: @material.below_reorder_level?
          },
          risk: risk_view,
          documents: @material.material_documents.map do |doc|
            { id: doc.id, materialId: doc.material_id, kind: doc.kind, name: doc.name,
              url: doc.url, byteSize: doc.byte_size, contentType: doc.content_type,
              createdAt: doc.created_at&.iso8601 }
          end
        }
      end

      private

      def set_material
        @material = Material.includes(:supplier, :material_risk_profile,
                                      :alternative_suppliers, :material_documents).find(params[:id])
      end
    end
  end
end
