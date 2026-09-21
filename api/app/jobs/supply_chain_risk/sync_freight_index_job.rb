module SupplyChainRisk
  # Syncs freight indices for the trend display (every 6h).
  class SyncFreightIndexJob < ApplicationJob
    queue_as :risk_polling

    def perform
      written = 0
      %w[freightos_fbx].each do |key|
        provider = Infrastructure::ProviderRegistry.resolve(key)
        next unless provider.available?

        subject = Domain::Subject.new(
          material_id: 'index', name: 'Frachtindex', article_number: nil,
          origin_country: 'CN', destination_country: 'DE', hs_code: nil,
          shipping_route: 'CN-SHA -> DE-HAM', transport_mode: 'sea',
          freight_cost_trend: 'stable', supplier_name: nil,
          is_single_source: false, supplier_rating: nil, lead_time_days: 45,
          historical_delay_count: 0, historical_delay_days: 0,
          last_disruption_at: nil, last_disruption_cause: nil,
          unit_net_price_cents: 0, manual_level: nil, manual_note: nil
        )
        draft = provider.assess(subject)
        Rails.cache.write('scr:freight_index', draft&.to_h, expires_in: 6.hours) if draft
        written += 1
      rescue StandardError => e
        Rails.logger.warn("[supply-chain-risk] freight sync #{key} failed: #{e.message}")
      end
      written
    end
  end
end
