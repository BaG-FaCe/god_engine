module SupplyChainRisk
  # Polls every event-capable open-data provider for origin countries
  # (every 30 min per recurring.yml).
  #
  # The provider list is derived from the catalogue (free tier, `events`
  # capable) instead of being hardcoded, so adding ReliefWeb or any future
  # feed is a catalogue change, not a job change.
  class PollDisasterAlertsJob < ApplicationJob
    queue_as :risk_polling

    def perform
      since = 24.hours.ago
      written = 0
      event_capable_provider_keys.each do |key|
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

    private

    def event_capable_provider_keys
      Infrastructure::ProviderCatalogue.free.select do |descriptor|
        descriptor.provider_class.instance_method_list.include?(:events)
      end.map(&:key)
    rescue StandardError => e
      # Fail open to the known-good set so a broken catalogue entry cannot
      # silently disable the early-warning feed.
      Rails.logger.warn("[supply-chain-risk] poll provider discovery failed: #{e.message}")
      %w[gdacs usgs_earthquake open_meteo reliefweb]
    end
  end
end
