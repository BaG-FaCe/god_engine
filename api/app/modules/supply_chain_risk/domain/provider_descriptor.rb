module SupplyChainRisk
  module Domain
    # Static metadata about a risk data source.
    #
    # The registry stores descriptors, and the API exposes them so an operator can
    # see *which* sources are available, which are configured and what they cost
    # in terms of rate limits - without any provider code having to run.
    ProviderDescriptor = Data.define(
      :key, :name, :tier, :category, :provider_class_name, :description,
      :requires_api_key, :cache_ttl_minutes, :rate_limit_per_minute,
      :dimensions, :docs_url, :env_keys, :cost_note
    ) do
      def self.build(**kwargs)
        new(
          key: kwargs.fetch(:key),
          name: kwargs.fetch(:name),
          tier: kwargs.fetch(:tier),
          category: kwargs.fetch(:category),
          provider_class_name: kwargs.fetch(:provider_class_name),
          description: kwargs.fetch(:description),
          requires_api_key: kwargs.fetch(:requires_api_key, false),
          cache_ttl_minutes: kwargs.fetch(:cache_ttl_minutes, 360),
          rate_limit_per_minute: kwargs.fetch(:rate_limit_per_minute, 60),
          dimensions: kwargs.fetch(:dimensions, []),
          docs_url: kwargs[:docs_url],
          env_keys: kwargs.fetch(:env_keys, []),
          cost_note: kwargs[:cost_note]
        )
      end

      def free?
        tier.to_s == 'free'
      end

      def paid?
        tier.to_s == 'paid'
      end

      def internal?
        tier.to_s == 'internal'
      end

      # Resolves the provider class lazily by name. Storing the name instead of
      # the class object keeps the registry valid across Rails code reloading.
      def provider_class
        provider_class_name.constantize
      end

      def to_h
        {
          key: key,
          name: name,
          tier: tier,
          category: category,
          description: description,
          requiresApiKey: requires_api_key,
          cacheTtlMinutes: cache_ttl_minutes,
          rateLimitPerMinute: rate_limit_per_minute,
          dimensions: dimensions,
          docsUrl: docs_url,
          envKeys: env_keys,
          costNote: cost_note
        }
      end
    end
  end
end