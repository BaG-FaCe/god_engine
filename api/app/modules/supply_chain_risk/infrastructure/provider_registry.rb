module SupplyChainRisk
  module Infrastructure
    # Resolves providers and merges the static catalogue with the per-project
    # configuration.
    #
    # This is the *only* place that knows both sides, which keeps the application
    # services free of configuration plumbing and makes "which providers run for
    # this project?" a single, testable question.
    class ProviderRegistry
      class UnknownProvider < StandardError; end

      class << self
        def descriptors
          ProviderCatalogue.all
        end

        def find(key)
          ProviderCatalogue.find(key)
        end

        def find!(key)
          find(key) || raise(UnknownProvider, "Unbekannter Risiko-Provider: #{key}")
        end

        def keys
          ProviderCatalogue.keys
        end

        # Instantiates a provider with an injected context.
        def resolve(key, context: nil)
          descriptor = find!(key)
          descriptor.provider_class.instantiate(
            context: context || Domain::ProviderContext.new(descriptor: descriptor)
          )
        end

        # Providers that would run for a project, in priority order.
        #
        # Priority: project configured providers first (by `priority`), then the
        # free/open-data providers, then the always-available internal model.
        # A provider is skipped when it needs a key that is missing.
        def active_for(project, include_paid: true)
          configured = RiskProviderConfig.for_project(project).enabled.ordered.index_by(&:provider_key)

          descriptors
            .select { |descriptor| include_paid || !descriptor.paid? }
            .select { |descriptor| usable?(descriptor, configured[descriptor.key]) }
            .sort_by do |descriptor|
              config = configured[descriptor.key]
              [config&.priority || default_priority(descriptor), descriptor.key]
            end
        end

        def usable?(descriptor, config)
          # Explicitly disabled in the project configuration.
          return false if config && !config.enabled

          return true unless descriptor.requires_api_key

          config&.api_key_present? || ProviderCatalogue.configured?(descriptor)
        end

        # Default ordering used when a project has no explicit configuration.
        # Internal sources come last so an external answer always wins when both
        # exist.
        def default_priority(descriptor)
          case descriptor.tier.to_s
          when 'paid' then 10
          when 'free' then 20
          else 900
          end
        end

        # Builds the API representation: catalogue + configuration state + last
        # run status. The API key itself is never exposed.
        def statuses(project = nil)
          configs = RiskProviderConfig.for_project(project).index_by(&:provider_key)
          runs = latest_runs

          descriptors.map do |descriptor|
            config = configs[descriptor.key]
            run = runs[descriptor.key]

            descriptor.to_h.merge(
              configured: configured?(descriptor, config),
              enabled: config ? config.enabled : true,
              apiKeyPresent: config&.api_key_present? || false,
              apiKeyHint: config&.api_key_hint,
              pollIntervalMinutes: config&.poll_interval_minutes,
              priority: config&.priority || default_priority(descriptor),
              lastRunAt: config&.last_run_at || run&.finished_at,
              lastStatus: config&.last_run_status || (run ? run.status : 'never_run'),
              lastError: config&.last_error,
              consecutiveFailures: config&.consecutive_failures || 0,
              requestsToday: RiskProviderRun.where(provider_key: descriptor.key)
                                             .since(24.hours.ago).sum(:requests_made)
            )
          end
        end

        def configured?(descriptor, config = nil)
          return true unless descriptor.requires_api_key

          (config&.api_key_present? || false) || ProviderCatalogue.configured?(descriptor)
        end

        private

        def latest_runs
          RiskProviderRun.order(started_at: :desc)
                         .limit(200)
                         .group_by(&:provider_key)
                         .transform_values(&:first)
        end
      end
    end
  end
end