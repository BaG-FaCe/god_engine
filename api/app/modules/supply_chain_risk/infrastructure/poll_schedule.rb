module SupplyChainRisk
  module Infrastructure
    # Answers "which provider should poll now, and for which project scope?".
    #
    # Per-project provider configuration (Update-Prompt Aufgabe 1) means the poll
    # interval is not a property of the job any more but of the
    # `risk_provider_configs` row:
    #
    #   * a project override wins over the catalogue default
    #   * `enabled: false` disables the provider for that project
    #   * a provider that is configured for several projects is polled once per
    #     scope that is due - the events themselves are global (`RiskEvent` has no
    #     mandatory project) and the `(source, source_event_id)` unique index makes
    #     the overlapping polls idempotent
    #
    # Projects without any configuration keep working: they fall back to the
    # catalogue default interval, so an unconfigured installation still polls.
    class PollSchedule
      # Used when neither a project override nor a catalogue entry defines one.
      DEFAULT_INTERVAL_MINUTES = 30

      Scope = Data.define(:provider_key, :project_id, :config, :interval_minutes) do
        def configured?
          !config.nil?
        end

        def due?
          return true if config.nil?
          return false if config.last_run_at.nil?

          config.last_run_at + interval_minutes.minutes <= Time.current
        end

        def mark_success!(at: Time.current)
          config&.mark_success!(at: at)
        end

        def mark_failure!(error)
          config&.mark_failure!(error)
        end

        def to_h
          { providerKey: provider_key, projectId: project_id,
            intervalMinutes: interval_minutes, configured: configured? }
        end
      end

      class << self
        # @param provider_keys [Array<String>]
        # @return [Array<Scope>] scopes that are enabled and due right now
        def due(provider_keys:, now: Time.current)
          Array(provider_keys).filter_map { |key| scope_for(key, now: now) }
        end

        # Picks the scope to poll for one provider:
        #   * no configuration        -> catalogue default, always due
        #   * enabled + due overrides -> the first such scope (highest priority)
        #   * everything disabled     -> nil
        def scope_for(provider_key, now: Time.current)
          configs = RiskProviderConfig.where(provider_key: provider_key.to_s)
                                      .order(:priority, :provider_key)
                                      .to_a

          if configs.empty?
            return Scope.new(provider_key: provider_key.to_s, project_id: nil, config: nil,
                             interval_minutes: default_interval(provider_key))
          end

          config = configs.find { |candidate| candidate.enabled && due?(candidate, now) }
          return nil if config.nil?

          Scope.new(provider_key: provider_key.to_s, project_id: config.project_id,
                    config: config, interval_minutes: config.poll_interval_minutes)
        end

        # Catalogue TTL is a reasonable stand-in for a poll interval: it is the
        # "how often is this data worth refreshing" number the catalogue already
        # documents per source.
        def default_interval(provider_key)
          descriptor = ProviderCatalogue.find(provider_key)
          (descriptor&.cache_ttl_minutes.presence || DEFAULT_INTERVAL_MINUTES)
        end

        def due?(config, now = Time.current)
          return true if config.last_run_at.nil?

          config.last_run_at + config.poll_interval_minutes.minutes <= now
        end
      end
    end
  end
end
