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
      def cached(namespace, key)
        cache_key = ['scr', namespace, key].join(':')
        cached_value = cache.read(cache_key)
        return cached_value unless cached_value.nil?

        value = yield
        cache.write(cache_key, value, expires_in: cache_ttl) unless value.nil?
        value
      end

      def log(level, message, **payload)
        logger.public_send(level, "[supply-chain-risk] #{message} #{payload.inspect}")
      rescue NoMethodError
        logger.info("[supply-chain-risk] #{message} #{payload.inspect}")
      end

      private

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