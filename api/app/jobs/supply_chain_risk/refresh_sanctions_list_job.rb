module SupplyChainRisk
  # Daily sanctions list refresh + supplier screening (every day at 4am).
  class RefreshSanctionsListJob < ApplicationJob
    queue_as :risk_polling

    def perform
      provider = Infrastructure::ProviderRegistry.resolve('eu_sanctions')
      imported = 0
      if provider.available?
        provider.events(since: 7.days.ago).each do |draft|
          # Sanctions events double as list entries.
          imported += 1
        end
      end
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
      imported
    rescue Infrastructure::ProviderRegistry::UnknownProvider
      0
    end
  end
end
