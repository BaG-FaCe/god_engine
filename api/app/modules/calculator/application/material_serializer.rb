module Calculator
  module Application
    # Serializer for the material aggregate (Tab 1 + risk traffic light).
    #
    # Lives in its own namespace instead of reopening `Serializers` so Zeitwerk
    # can map the file name to a constant.
    module MaterialSerializer
      class << self
        def call(material)
          profile = material.material_risk_profile
          {
            id: material.id, projectId: material.project_id, name: material.name,
            materialType: material.material_type, supplierId: material.supplier_id,
            supplierName: material.supplier&.name, articleNumber: material.article_number,
            description: material.description, imageUrl: material.image_url,
            unit: material.unit, unitPriceCents: material.unit_price_cents,
            priceIncludesTax: material.price_includes_tax, quantity: material.quantity.to_f,
            minOrderQuantity: material.min_order_quantity.to_f,
            leadTimeValue: material.lead_time_value.to_f, leadTimeUnit: material.lead_time_unit,
            leadTimeDays: material.lead_time_days, storageLocation: material.storage_location,
            deliveryAddress: material.delivery_address, currency: material.currency,
            stockQuantity: material.stock_quantity.to_f, reorderLevel: material.reorder_level.to_f,
            position: material.position, riskScore: material.risk_score,
            riskLevel: material.risk_level,
            lastRiskCheckedAt: material.last_risk_checked_at&.iso8601,
            riskProfile: profile && profile_hash(profile),
            alternativeSuppliers: material.alternative_suppliers.map do |alt|
              Serializers.alternative_supplier(alt)
            end,
            createdAt: material.created_at&.iso8601, updatedAt: material.updated_at&.iso8601
          }
        end

        def profile_hash(profile)
          {
            originCountry: profile.origin_country, hsCode: profile.hs_code,
            shippingRoute: profile.shipping_route, transportMode: profile.transport_mode,
            isSingleSource: profile.is_single_source,
            historicalDelayCount: profile.historical_delay_count,
            historicalDelayDays: profile.historical_delay_days,
            lastDisruptionAt: profile.last_disruption_at&.iso8601,
            lastDisruptionCause: profile.last_disruption_cause,
            lastDisruptionNote: profile.last_disruption_note,
            freightCostTrend: profile.freight_cost_trend,
            manualRiskLevel: profile.manual_risk_level,
            manualRiskNote: profile.manual_risk_note
          }
        end
      end
    end
  end
end