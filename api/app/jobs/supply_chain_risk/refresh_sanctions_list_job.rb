module SupplyChainRisk
  # Daily sanctions list sync + supplier screening (every day at 4am).
  #
  # Syncs every catalogue provider that implements `sync_list!` (currently the
  # EU consolidated list and the US OFAC SDN list), then screens all suppliers
  # against the locally cached entries. A "clear" from a stale list is worth
  # more than an error, which is why the lists live in the database.
  class RefreshSanctionsListJob < ApplicationJob
    queue_as :risk_polling

    def perform
      imported = sync_lists
      screen_suppliers
      imported
    end

    private

    def sync_lists
      imported = 0
      Infrastructure::ProviderCatalogue.free.each do |descriptor|
        provider = Infrastructure::ProviderRegistry.resolve(descriptor.key)
        next unless provider.respond_to?(:sync_list!)
        next unless provider.available?

        RiskProviderRun.track(descriptor.key) do |run|
          count = provider.sync_list!
          imported += count
          run.update!(events_written: count)
        end
      rescue StandardError => e
        Rails.logger.warn("[supply-chain-risk] sanctions sync #{descriptor.key} failed: #{e.message}")
      end
      imported
    end

    def screen_suppliers
      Supplier.find_each do |supplier|
        hits = SanctionsEntry.search(supplier.name)
        if hits.exists?
          supplier.apply_sanctions_result!(
            status: 'flagged', details: { hits: hits.limit(5).pluck(:entity_name) }
          )
        elsif supplier.sanctions_status == 'unknown'
          supplier.apply_sanctions_result!(status: 'clear', details: { checkedAt: Time.current.iso8601 })
        end
      end
    end
  end
end
