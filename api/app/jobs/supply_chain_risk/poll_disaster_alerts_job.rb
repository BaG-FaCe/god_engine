module SupplyChainRisk
  # Polls GDACS/USGS/Open-Meteo for origin countries (every 30 min).
  class PollDisasterAlertsJob < ApplicationJob
    queue_as :risk_polling

    PROVIDERS = %w[gdacs usgs_earthquake open_meteo].freeze

    def perform
      since = 24.hours.ago
      written = 0
      PROVIDERS.each do |key|
        provider = Infrastructure::ProviderRegistry.resolve(key)
        provider.events(since: since).each do |draft|
          draft.persist!
          written += 1
        end
      rescue StandardError => e
        Rails.logger.warn("[supply-chain-risk] poll #{key} failed: #{e.message}")
      end
      written
    end
  end
end
