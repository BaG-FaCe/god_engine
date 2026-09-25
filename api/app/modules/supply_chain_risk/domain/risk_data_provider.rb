module SupplyChainRisk
  module Domain
    # The single contract every risk data source has to fulfil.
    #
    # Implementations must be *stateless per call* and must never raise for
    # expected upstream problems - they return `nil` (no assessment possible) and
    # log the reason instead. Unexpected errors are allowed to bubble up so the
    # job wrapper can record them in `risk_provider_runs`.
    #
    # Two provider families exist:
    #
    #   * `FreeData::*`  - open data (no key or a free key)
    #   * `PaidData::*`  - commercial SCRM / visibility platforms
    #   * `Internal*`    - the built-in heuristic and the manual fallback
    #
    # The tier is metadata only: the calculation never treats a paid answer as
    # more authoritative, it only weights it by `confidence`.
    class RiskDataProvider
      class NotConfigured < StandardError; end
      class Unavailable < StandardError; end

      # Instances are cheap - they only hold the injected context.
      def initialize(context: nil)
        @context = context || ProviderContext.new(descriptor: self.class.descriptor)
      end

      attr_reader :context

      class << self
        # @return [ProviderDescriptor]
        def descriptor
          raise NotImplementedError, "#{name} must define .descriptor"
        end

        def key
          descriptor.key
        end

        def tier
          descriptor.tier
        end

        def requires_api_key?
          descriptor.requires_api_key
        end

        def configured?
          return true unless requires_api_key?

          descriptor.env_keys.any? { |key| ENV[key.to_s].present? }
        end

        def instantiate(context: nil)
          new(context: context || ProviderContext.new(
            descriptor: descriptor
          ))
        end
      end

      # Per-material risk assessment.
      #
      # @param subject [Subject]
      # @return [AssessmentDraft, nil]
      def assess(subject)
        raise NotImplementedError, "#{self.class.name}#assess is not implemented"
      end

      # Bulk early-warning signals (disaster alerts, port congestion, ...).
      # Providers that only answer per material return an empty array.
      #
      # @param since [Time]
      # @return [Array<EventDraft>]
      def events(since: 24.hours.ago)
        []
      end

      # Bulk feeds are polled by background jobs. An unreachable upstream must
      # degrade to "no new signals" - never to a failed job - so callers use this
      # instead of `events` directly. The raw `events` may still raise a
      # `JsonClient::Error`; that is the documented seam for callers that want to
      # record the failure themselves.
      def events_safely(since: 24.hours.ago)
        events(since: since)
      rescue Shared::Infrastructure::Http::JsonClient::Error => e
        context.log(:warn, "#{key}: Ereignisabruf fehlgeschlagen", error: e.message)
        []
      end

      # Contract test used by `POST /api/v1/risk_providers/:key/probe`.
      # Should be cheap and must not write anything.
      #
      # @return [Hash] { ok:, message:, latencyMs:, sampleScore: }
      def probe
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        subject = probe_subject
        draft = assess(subject)
        latency = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

        if draft.nil?
          { ok: false, message: 'Provider lieferte keine Bewertung', latencyMs: latency,
            sampleScore: nil }
        else
          { ok: true, message: "Beispielbewertung: Score #{draft.risk_score}", latencyMs: latency,
            sampleScore: draft.risk_score }
        end
      rescue NotConfigured => e
        { ok: false, message: e.message, latencyMs: 0, sampleScore: nil, reason: 'not_configured' }
      rescue Unavailable => e
        { ok: false, message: e.message, latencyMs: 0, sampleScore: nil, reason: 'unavailable' }
      end

      # True when the provider can answer right now (key present / open data).
      #
      # Resolution order matters: a key configured *per project* in
      # `risk_provider_configs` must win over the process environment, otherwise
      # the per-project configuration (Update-Prompt Aufgabe 1) would be ignored
      # for every paid adapter.
      def available?
        return context.configured? if context.respond_to?(:configured?)

        self.class.configured?
      end

      def descriptor
        self.class.descriptor
      end

      def key
        self.class.key
      end

      def tier
        self.class.tier
      end

      protected

      # A harmless example used by the probe endpoint.
      def probe_subject
        Subject.new(
          material_id: 'probe', name: 'Probe-Material', article_number: nil,
          origin_country: 'CN', destination_country: 'DE', hs_code: '84818099',
          shipping_route: 'CN-SHA -> DE-HAM', transport_mode: 'sea',
          freight_cost_trend: 'stable', supplier_name: 'Probe Supplier',
          is_single_source: false, supplier_rating: 3, lead_time_days: 45,
          historical_delay_count: 0, historical_delay_days: 0,
          last_disruption_at: nil, last_disruption_cause: nil,
          unit_net_price_cents: 1000, manual_level: nil, manual_note: nil
        )
      end

      # Builds the draft with this provider's identity pre-filled, so an adapter
      # cannot accidentally report another provider's key.
      #
      # When the provider had to fall back to a cached value because the upstream
      # API was unreachable (`ProviderContext#last_read_stale?`), the draft is
      # explicitly marked: the reason carries a "stale" note and the confidence is
      # halved. That keeps the "never fail hard, but never pretend to be fresh
      # either" promise (Update-Prompt Aufgabe 1).
      def draft(risk_score:, **options)
        options = mark_stale(options) if stale_context?

        AssessmentDraft.build(
          provider_key: key,
          provider_name: descriptor.name,
          provider_tier: tier,
          risk_score: risk_score,
          expires_in: options.delete(:expires_in) || descriptor.cache_ttl_minutes.minutes,
          **options
        )
      end

      STALE_REASON_SUFFIX =
        ' ⚠ Stale-Fallback: Provider derzeit nicht erreichbar, letzter bekannter Wert verwendet.'
      STALE_CONFIDENCE_FACTOR = BigDecimal('0.5')

      private

      def stale_context?
        context.respond_to?(:last_read_stale?) && context.last_read_stale?
      end

      def mark_stale(options)
        options[:reason] = "#{options[:reason]}#{STALE_REASON_SUFFIX}".strip
        confidence = options[:confidence]
        if confidence
          options[:confidence] = (BigDecimal(confidence.to_s) * STALE_CONFIDENCE_FACTOR).round(4)
        end
        options
      end
    end
  end
end