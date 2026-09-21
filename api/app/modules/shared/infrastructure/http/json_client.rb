require 'faraday'
require 'faraday/retry'
require 'faraday/follow_redirects'

module Shared
  module Infrastructure
    module Http
      # The one outbound HTTP client used by every external provider adapter.
      #
      # It centralises the four things that are easy to get wrong when calling
      # third party APIs from a background job:
      #
      #   1. **timeouts**    - a hanging provider must not block a worker
      #   2. **retries**     - transient 5xx / connection resets are retried with
      #      exponential backoff, only for idempotent methods
      #   3. **rate limits** - every call is counted per provider so free tiers are
      #      never exceeded (see `RateLimiter`)
      #   4. **caching**     - successful bodies are cached in Solid Cache for the
      #      provider's TTL, so a short poll interval cannot hammer an API
      #
      # Errors are normalised, so adapters only ever rescue these five types.
      class JsonClient
        class Error < StandardError; end
        class Timeout < Error; end
        class Unauthorized < Error; end
        class RateLimited < Error; end
        class Unavailable < Error; end
        class BadRequest < Error; end

        DEFAULT_OPEN_TIMEOUT = 5
        DEFAULT_READ_TIMEOUT = 15
        DEFAULT_MAX_RETRIES = 3

        Result = Data.define(:status, :body, :headers, :url, :duration_ms, :cached) do
          def success?
            status.to_i.between?(200, 299)
          end

          def to_h
            { status: status, url: url, durationMs: duration_ms, cached: cached }
          end
        end

        attr_reader :rate_limiter, :cache, :logger

        def initialize(rate_limiter: nil, cache: nil, logger: nil, user_agent: nil)
          @cache = cache || Rails.cache
          @rate_limiter = rate_limiter || RateLimiter.new(cache: @cache)
          @logger = logger || Rails.logger
          @user_agent = user_agent || default_user_agent
        end

        # GET returning parsed JSON, or nil for an empty body.
        #
        # @param provider_key [String] used for the rate limit budget
        # @param cache_key [String, nil] when given, the parsed body is cached
        # @param ttl [ActiveSupport::Duration, nil]
        def get_json(url, params: {}, headers: {}, provider_key: nil, cache_key: nil,
                     ttl: nil, max_wait: 30)
          unless cache_key.nil?
            cached = @cache.read(cache_key)
            return cached unless cached.nil?
          end

          body = get(url, params: params, headers: headers,
                          provider_key: provider_key, max_wait: max_wait)
          parsed = body.present? ? JSON.parse(body) : nil
          @cache.write(cache_key, parsed, expires_in: ttl) if cache_key && ttl && !parsed.nil?
          parsed
        rescue JSON::ParserError => e
          raise BadRequest, "Ungültige JSON-Antwort von #{url}: #{e.message}"
        end

        # Raw GET returning the response body as a String.
        def get(url, params: {}, headers: {}, provider_key: nil, max_wait: 30)
          request(:get, url, params: params, headers: headers,
                             provider_key: provider_key, max_wait: max_wait)
        end

        def post_json(url, payload:, headers: {}, provider_key: nil, max_wait: 30)
          body = request(:post, url, payload: payload, headers: headers,
                                    provider_key: provider_key, max_wait: max_wait)
          body.present? ? JSON.parse(body) : nil
        rescue JSON::ParserError => e
          raise BadRequest, "Ungültige JSON-Antwort von #{url}: #{e.message}"
        end

        # Performs the call, applying the rate limit and mapping status codes onto
        # the error types above.
        def request(method, url, params: {}, payload: nil, headers: {}, provider_key: nil,
                    max_wait: 30)
          limit = quota_for(provider_key)
          @rate_limiter.acquire!(provider_key, limit: limit, max_wait: max_wait) if provider_key
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          response = connection.public_send(method) do |req|
            req.url(url)
            req.params.update(stringify(params)) if params.present?
            req.headers.update(default_headers.merge(stringify(headers)))
            req.body = payload.to_json if payload
          end

          duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
          handle_status(response, url, duration)
          response.body
        rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
          raise Timeout, "#{url} nicht erreichbar: #{e.message}"
        rescue RateLimiter::QuotaExceeded => e
          raise RateLimited, e.message
        end

        private

        def handle_status(response, url, duration)
          status = response.status.to_i
          log_call(url, status, duration)

          case status
          when 200..299 then nil
          when 401, 403 then raise Unauthorized, "Zugriff verweigert (#{status}) für #{url}"
          when 429 then raise RateLimited, "Rate limit erreicht (#{status}) für #{url}"
          when 400..499 then raise BadRequest, "Anfrage abgelehnt (#{status}) für #{url}"
          else raise Unavailable, "Provider nicht verfügbar (#{status}) für #{url}"
          end
        end

        def log_call(url, status, duration)
          @logger.info("[http] #{status} #{duration}ms #{redact(url)}")
        end

        # Never log credentials that were passed as query parameters.
        def redact(url)
          url.to_s.gsub(/(api[_-]?key|apikey|token|access_key)=([^&]+)/i, '\1=***')
        end

        def quota_for(provider_key)
          return 0 if provider_key.blank?

          descriptor = SupplyChainRisk::Infrastructure::ProviderRegistry.find(provider_key)
          descriptor&.rate_limit_per_minute || 60
        end

        def connection
          @connection ||= Faraday.new do |faraday|
            faraday.request :retry, max: max_retries, interval: 0.5,
                                    interval_randomness: 0.5, backoff_factor: 2,
                                    exceptions: [Faraday::TimeoutError,
                                                 Faraday::ConnectionFailed],
                                    retry_statuses: [408, 429, 500, 502, 503, 504],
                                    methods: %i[get head options]
            faraday.response :follow_redirects, limit: 3
            faraday.options.open_timeout = open_timeout
            faraday.options.timeout = read_timeout
            faraday.adapter Faraday.default_adapter
          end
        end

        def default_headers
          {
            'User-Agent' => @user_agent,
            'Accept' => 'application/json'
          }
        end

        def stringify(hash)
          (hash || {}).each_with_object({}) do |(key, value), memo|
            memo[key.to_s] = value
          end
        end

        def default_user_agent
          ENV.fetch('HTTP_USER_AGENT',
                    'GodEngine-RiskIntelligence/1.0 (+https://god-engine.local)')
        end

        def open_timeout
          Float(ENV.fetch('HTTP_OPEN_TIMEOUT', DEFAULT_OPEN_TIMEOUT))
        end

        def read_timeout
          Float(ENV.fetch('HTTP_READ_TIMEOUT', DEFAULT_READ_TIMEOUT))
        end

        def max_retries
          Integer(ENV.fetch('HTTP_MAX_RETRIES', DEFAULT_MAX_RETRIES))
        end
      end
    end
  end
end