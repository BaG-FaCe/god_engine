require 'yaml'

module SupplyChainRisk
  module Infrastructure
    # Loads the provider catalogue from `config/risk_providers.yml`.
    #
    # The file is cached in memory after the first read. Only strings and numbers
    # are stored (the provider class is kept as a *name*, not a constant), so the
    # cache survives Rails code reloading in development.
    module ProviderCatalogue
      NAMESPACE = 'SupplyChainRisk::Infrastructure::Providers'
      CONFIG_PATH = 'config/risk_providers.yml'

      class << self
        def all
          @all ||= load_file.freeze
        end

        def find(key)
          all.find { |descriptor| descriptor.key == key.to_s }
        end

        # Raises instead of returning nil - used where a missing descriptor is a
        # programming error (e.g. a provider asking for its own descriptor).
        def find!(key)
          find(key) || raise(ArgumentError, "Provider '#{key}' ist nicht im Katalog (#{CONFIG_PATH})")
        end

        def keys
          all.map(&:key)
        end

        def by_tier(tier)
          all.select { |descriptor| descriptor.tier.to_s == tier.to_s }
        end

        def free
          by_tier('free')
        end

        def paid
          by_tier('paid')
        end

        def internal
          by_tier('internal')
        end

        # Descriptors whose API key is present (or which need none).
        def configured
          all.select { |descriptor| configured?(descriptor) }
        end

        def configured?(descriptor)
          return true unless descriptor.requires_api_key

          descriptor.env_keys.any? { |key| ENV[key.to_s].present? }
        end

        def reload!
          @all = nil
          all
        end

        private

        def load_file
          path = Rails.root.join(CONFIG_PATH)
          unless File.exist?(path)
            Rails.logger.warn("[supply-chain-risk] #{CONFIG_PATH} fehlt - keine Provider registriert.")
            return []
          end

          raw = YAML.safe_load(ERB.new(File.read(path)).result, aliases: true) || {}
          Array(raw['providers']).map { |entry| build_descriptor(entry) }
        end

        def build_descriptor(entry)
          raise ArgumentError, "Provider ohne 'key' in #{CONFIG_PATH}" if entry['key'].blank?

          Domain::ProviderDescriptor.build(
            key: entry.fetch('key'),
            name: entry.fetch('name'),
            tier: entry.fetch('tier'),
            category: entry.fetch('category'),
            provider_class_name: "#{NAMESPACE}::#{entry.fetch('class')}",
            description: entry.fetch('description'),
            requires_api_key: entry.fetch('requiresApiKey', false),
            cache_ttl_minutes: entry.fetch('cacheTtlMinutes', 360),
            rate_limit_per_minute: entry.fetch('rateLimitPerMinute', 60),
            dimensions: entry.fetch('dimensions', []),
            docs_url: entry['docsUrl'],
            env_keys: entry.fetch('envKeys', []),
            cost_note: entry['costNote']
          )
        end
      end
    end
  end
end