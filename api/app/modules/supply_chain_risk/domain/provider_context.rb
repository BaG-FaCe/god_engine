module SupplyChainRisk
  module Domain
    # Everything a provider needs from the outside world, injected explicitly.
    #
    # Providers never touch `Rails.cache`, `ENV`, `Rails.logger` or
    # `Faraday.new` directly; they receive this context. That single decision is
    # what makes every adapter testable with a fake context and what allows the
    # same adapter to run inside a Solid Queue worker, a console session or a
    # rake task.
    class ProviderContext
      attr_reader :http, :cache, :logger, :config, :clock, :project_id

      def initialize(http: nil, cache: nil, logger: nil, config: nil, clock: nil,
                     project_id: nil, descriptor: nil)
        @descriptor = descriptor
        @http = http || Shared::Infrastructure::Http::JsonClient.new(cache: cache)
        @cache = cache || Rails.cache
        @logger = logger || Rails.logger
        @config = config || {}
        @clock = clock || Time
        @project_id = project_id
      end

      def descriptor
        @descriptor
      end

      # API key resolution order:
      #   1. per project configuration (encrypted in `risk_provider_configs`)
      #   2. an environment variable listed in the descriptor
      #   3. nil -> the provider reports itself as "not configured"
      def api_key
        @api_key ||= begin
          from_config = config[:api_key].presence || config['api_key'].presence
          from_config || env_api_key
        end
      end

      def api_secret
        config[:api_secret].presence || config['api_secret'].presence || env_value(:secret)
      end

      def configured?
        return true unless @descriptor&.requires_api_key

        api_key.present?
      end

      def cache_ttl
        (@descriptor&.cache_ttl_minutes || 360).minutes
      end

      def rate_limit_per_minute
        @descriptor&.rate_limit_per_minute || 60
      end

      def now
        clock.respond_to?(:current) ? clock.current : clock.now
      end

      # Cache helper that transparently honours the descriptor's TTL so no
      # adapter can accidentally hammer an upstream API.
      #
      # Stale fallback (Update-Prompt Aufgabe 1): every successful read is *also*
      # written to a long-lived `:stale` sibling key. When the upstream API is
      # unreachable and the fresh entry has expired, the last known value is
      # returned instead of raising - the calculator never fails hard because a
      # third party is down. Adapters can mark their answer as outdated through
      # `last_read_stale?` (see `Domain::RiskDataProvider#draft`).
      def cached(namespace, key)
        cache_key = ['scr', namespace, key].join(':')
        cached_value = cache.read(cache_key)
        return cached_value unless cached_value.nil?

        value = yield
        unless value.nil?
          cache.write(cache_key, value, expires_in: cache_ttl)
          cache.write(stale_cache_key(cache_key), value, expires_in: stale_cache_ttl)
        end
        value
      rescue Shared::Infrastructure::Http::JsonClient::Error => e
        fallback = cache.read(stale_cache_key(cache_key))
        raise if fallback.nil?

        @last_read_stale = true
        log(:warn, "#{namespace}:#{key} nicht erreichbar - verwende letzten bekannten Wert",
            error: e.message)
        fallback
      end

      # True when the most recent `cached` read had to fall back to an outdated
      # value. Scoped to this context, which is built per provider call.
      def last_read_stale?
        @last_read_stale == true
      end

      def log(level, message, **payload)
        logger.public_send(level, "[supply-chain-risk] #{message} #{payload.inspect}")
      rescue NoMethodError
        logger.info("[supply-chain-risk] #{message} #{payload.inspect}")
      end

      private

      STALE_SUFFIX = ':stale'

      # How much longer the "last known good" copy is retained than the fresh
      # one. 14x a 30 min TTL is ~7 hours, 14x a 24 h TTL is two weeks - enough to
      # survive a weekend outage without growing the cache database unbounded.
      STALE_TTL_MULTIPLIER = 14

      def stale_cache_key(cache_key)
        "#{cache_key}#{STALE_SUFFIX}"
      end

      def stale_cache_ttl
        cache_ttl * STALE_TTL_MULTIPLIER
      end

      def env_api_key
        env_value(:key)
      end

      def env_value(kind)
        keys = Array(@descriptor&.env_keys)
        candidate =
          case kind
          when :secret then keys.find { |k| k.to_s.end_with?('_SECRET') || k.to_s.end_with?('_CLIENT_SECRET') }
          else keys.find { |k| !k.to_s.end_with?('_SECRET') && !k.to_s.end_with?('_CLIENT_SECRET') }
          end
        candidate ? ENV[candidate.to_s].presence : nil
      end
    end
  end
end