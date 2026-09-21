module SupplyChainRisk
  module Domain
    # The question a provider is asked about one material.
    #
    # Deliberately a plain value object (not an Active Record instance) so that
    # providers can be tested with a one line fixture and so the risk module does
    # not depend on the calculator's persistence layout.
    Subject = Data.define(
      :material_id, :name, :article_number,
      :origin_country, :destination_country, :hs_code,
      :shipping_route, :transport_mode, :freight_cost_trend,
      :supplier_name, :is_single_source, :supplier_rating,
      :lead_time_days, :historical_delay_count, :historical_delay_days,
      :last_disruption_at, :last_disruption_cause,
      :unit_net_price_cents, :manual_level, :manual_note
    ) do
      def self.from_material(material)
        profile = material.material_risk_profile

        new(
          material_id: material.id,
          name: material.name,
          article_number: material.article_number,
          origin_country: profile&.origin_country,
          destination_country: nil,
          hs_code: profile&.hs_code,
          shipping_route: profile&.shipping_route,
          transport_mode: profile&.transport_mode,
          freight_cost_trend: profile&.freight_cost_trend || 'unknown',
          supplier_name: material.supplier&.name,
          is_single_source: profile&.is_single_source? || material.supplier&.is_single_source? || false,
          supplier_rating: material.supplier&.rating,
          lead_time_days: material.lead_time_days.to_i,
          historical_delay_count: profile&.historical_delay_count,
          historical_delay_days: profile&.historical_delay_days,
          last_disruption_at: profile&.last_disruption_at,
          last_disruption_cause: profile&.last_disruption_cause,
          unit_net_price_cents: material.net_unit_price_cents,
          manual_level: profile&.manual_risk_level,
          manual_note: profile&.manual_risk_note
        )
      end

      # Key used for cache lookups: identical subjects share a cache entry.
      def cache_fingerprint
        [material_id, origin_country, transport_mode, shipping_route, lead_time_days]
          .map(&:to_s).join('|')
      end

      def international?
        origin_country.present? && origin_country != destination_country
      end

      def to_h
        {
          materialId: material_id,
          name: name,
          articleNumber: article_number,
          originCountry: origin_country,
          destinationCountry: destination_country,
          hsCode: hs_code,
          shippingRoute: shipping_route,
          transportMode: transport_mode,
          freightCostTrend: freight_cost_trend,
          supplierName: supplier_name,
          isSingleSource: is_single_source,
          supplierRating: supplier_rating,
          leadTimeDays: lead_time_days,
          historicalDelayCount: historical_delay_count,
          historicalDelayDays: historical_delay_days,
          lastDisruptionAt: last_disruption_at&.iso8601,
          manualLevel: manual_level,
          unitNetPriceCents: unit_net_price_cents
        }
      end
    end
  end
end