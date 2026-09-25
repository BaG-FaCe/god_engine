module SupplyChainRisk
  # Polls every event-capable open-data provider for origin countries.
  #
  # The provider list is derived from the catalogue (free tier, `events`
  # capable) instead of being hardcoded, so adding ReliefWeb or any future
  # feed is a catalogue change, not a job change.
  #
  # Per-project configuration (Update-Prompt Aufgabe 1) is honoured through
  # `Infrastructure::PollSchedule`: a project can disable a provider or give it
  # its own poll interval, and the job only polls scopes that are actually due.
  # Because `EventDraft#persist!` upserts on `(source, source_event_id)`, polling
  # the same feed twice (or for two projects) never duplicates an event.
  class PollDisasterAlertsJob < ApplicationJob
    queue_as :risk_polling

    LOOKBACK = 24.hours

    def perform
      since = LOOKBACK.ago
      written = 0

      Infrastructure::PollSchedule.due(provider_keys: event_capable_provider_keys).each do |scope|
        written += poll(scope, since: since)
      end

      written
    end

    private

    def poll(scope, since:)
      provider = Infrastructure::ProviderRegistry.resolve(
        scope.provider_key,
        context: Domain::ProviderContext.new(
          descriptor: Infrastructure::ProviderRegistry.find(scope.provider_key),
          project_id: scope.project_id
        )
      )

      written = provider.events_safely(since: since).count do |draft|
        draft.persist!.present?
      end
      scope.mark_success!
      written
    rescue StandardError => e
      Rails.logger.warn("[supply-chain-risk] poll #{scope.provider_key} failed: #{e.message}")
      scope.mark_failure!(e)
      0
    end

    def event_capable_provider_keys
      Infrastructure::ProviderCatalogue.free.select do |descriptor|
        event_capable?(descriptor)
      end.map(&:key)
    rescue StandardError => e
      # Fail open to the known-good set so a broken catalogue entry cannot
      # silently disable the early-warning feed.
      Rails.logger.warn("[supply-chain-risk] poll provider discovery failed: #{e.message}")
      %w[gdacs usgs_earthquake open_meteo reliefweb]
    end

    # A provider counts as event capable when it *overrides* the no-op on the
    # base contract. Checking `instance_method_list` was not enough, because the
    # inherited `events` made every open-data source look event capable and the
    # job would call 14 adapters where 4 actually have a feed.
    def event_capable?(descriptor)
      owner = descriptor.provider_class.instance_method(:events).owner
      owner != Domain::RiskDataProvider
    end
  end
end
