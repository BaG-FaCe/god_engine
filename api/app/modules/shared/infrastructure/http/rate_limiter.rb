module Shared
  module Infrastructure
    module Http
      # Outbound rate limiter.
      #
      # Free provider tiers are unforgiving: exceeding a quota usually means a
      # multi-hour or multi-day lockout. Every adapter therefore passes through
      # this limiter, which enforces a per-provider requests-per-minute budget
      # using the shared cache (Solid Cache in production, so the limit holds
      # across all Puma workers and Solid Queue processes).
      #
      # A fixed window counter is used on purpose: it is cheap, survives process
      # restarts and is accurate enough for "do not exceed N per minute".
      class RateLimiter
        class QuotaExceeded < StandardError; end

        WINDOW_SECONDS = 60

        def initialize(cache: nil, clock: Time)
          @cache = cache || Rails.cache
          @clock = clock
        end

        # Blocks until a slot is available, then consumes it.
        #
        # @param key [String] provider key
        # @param limit [Integer] requests per minute
        # @param max_wait [Float] seconds we are willing to wait before failing
        # @return [Integer] the number of requests used in the current window
        def acquire!(key, limit:, max_wait: 30)
          return 0 if limit.to_i <= 0

          waited = 0.0
          loop do
            used = consume(key, limit)
            return used if used

            raise QuotaExceeded, "Rate limit für #{key} erreicht (#{limit}/min)" if waited >= max_wait

            sleep_seconds = [seconds_until_next_window, 1.0].min
            sleep(sleep_seconds)
            waited += sleep_seconds
          end
        end

        # Non-blocking check used by the monitoring endpoint.
        def used(key)
          @cache.read(counter_key(key, current_window)).to_i
        end

        def remaining(key, limit:)
          [limit.to_i - used(key), 0].max
        end

        def reset!(key)
          @cache.delete(counter_key(key, current_window))
        end

        private

        def consume(key, limit)
          cache_key = counter_key(key, current_window)
          count = @cache.read(cache_key).to_i
          return nil if count >= limit.to_i

          # `increment` is atomic where the store supports it; Solid Cache and the
          # memory store both do.
          new_value = @cache.increment(cache_key, 1, expires_in: WINDOW_SECONDS * 2)
          new_value = count + 1 if new_value.nil?
          new_value
        end

        def counter_key(key, window)
          "rate:#{key}:#{window}"
        end

        def current_window
          now.to_i / WINDOW_SECONDS
        end

        def seconds_until_next_window
          WINDOW_SECONDS - (now.to_i % WINDOW_SECONDS)
        end

        def now
          @clock.respond_to?(:current) ? @clock.current : @clock.now
        end
      end
    end
  end
end