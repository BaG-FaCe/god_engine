require 'base64'
require 'json'

module SupplyChainRisk
  module Infrastructure
    module Providers
      module PaidData
        # Shared implementation for all commercial SCRM / visibility vendors.
        #
        # Commercial risk APIs are contract-gated: you receive the endpoint and the
        # response schema only after signing, and schemas differ per customer and
        # per plan. Hard-coding a guessed schema for 19 vendors would be worse than
        # useless - it would silently produce wrong numbers.
        #
        # Instead each adapter is *declarative*: it names the vendor, the endpoint
        # and the default JSON pointers into the response. Because those pointers
        # can be overridden per project in `risk_provider_configs.config['mapping']`,
        # a newly contracted vendor can be connected without a deployment:
        #
        #   PATCH /api/v1/risk_providers/project44/configure
        #   { "apiKey": "...",
        #     "config": { "baseUrl": "https://...",
        #                 "mapping": { "riskScore": "/data/score" } } }
        #
        # Auth, timeouts, retries, rate limiting, caching, dimension normalisation,
        # credential redaction and error reporting all live here - a vendor file
        # only declares what makes that vendor *different*.
        class BaseAdapter < Domain::RiskDataProvider
          # Default JSON Pointers (RFC 6901) into a vendor response.
          DEFAULT_MAPPING = {
            'riskScore' => '/riskScore',
            'riskLevel' => '/riskLevel',
            'leadTimeVarianceDays' => '/leadTimeVarianceDays',
            'reason' => '/reason',
            'dimensions' => '/dimensions',
            'entityId' => '/id',
            'events' => '/events'
          }.freeze

          # Vendors express risk on many scales; these map the common labels onto
          # the platform's 0-100 integer scale.
          LEVEL_TO_SCORE = { 'low' => 20, 'medium' => 50, 'high' => 80, 'critical' => 95 }.freeze

          class << self
            # Subclasses override this with a frozen hash.
            def profile
              raise NotImplementedError, "#{name}.profile is not defined"
            end

            def descriptor
              @descriptor ||= Infrastructure::ProviderCatalogue.find!(profile.fetch(:key))
            end
          end

          def assess(subject)
            return not_configured if context.api_key.blank?

            payload = request_assessment(subject)
            return nil if payload.blank?

            score = extract_score(payload)
            return nil if score.nil?

            draft(
              risk_score: score,
              dimensions: extract_dimensions(payload),
              lead_time_variance_days: extract_integer(payload, 'leadTimeVarianceDays'),
              reason: extract_string(payload, 'reason') || default_reason(payload),
              data_sources: [self.class.descriptor.name],
              raw_payload: redact(payload),
              confidence: BigDecimal('0.95')
            )
          rescue Shared::Infrastructure::Http::JsonClient::Unauthorized
            not_configured
          rescue Shared::Infrastructure::Http::JsonClient::Error => e
            context.log(:warn, "#{key}: Abfrage fehlgeschlagen", error: e.message)
            nil
          end

          # Most vendors expose an incident/alert stream in addition to scores.
          def events(since: 24.hours.ago)
            return [] if context.api_key.blank?

            payload = request_events(since)
            Array(pointer(payload, mapping['events'])).filter_map { |entry| build_event(entry, since) }
          rescue Shared::Infrastructure::Http::JsonClient::Error
            []
          end

          # Verifies credentials without burning a data quota call.
          def probe
            if context.api_key.blank?
              return { ok: false, message: 'Kein API-Key hinterlegt', latencyMs: 0,
                       sampleScore: nil, reason: 'not_configured' }
            end

            super
          end

          protected

          def profile
            self.class.profile
          end

          # Vendor configuration overrides, in increasing precedence:
          # descriptor default -> adapter profile -> project configuration.
          def setting(key, default = nil)
            override = context.config[key.to_s] || context.config[key.to_sym]
            return override unless override.nil?

            profile.fetch(key.to_sym, default)
          end

          def base_url
            setting(:base_url).to_s.chomp('/')
          end

          def mapping
            @mapping ||= DEFAULT_MAPPING
                         .merge(stringify(profile.fetch(:mapping, {})))
                         .merge(stringify(context.config['mapping'] || context.config[:mapping] || {}))
          end

          def auth_headers
            case profile.fetch(:auth, :bearer).to_sym
            when :api_key_header
              { profile.fetch(:auth_header, 'X-API-KEY') => context.api_key.to_s }
            when :basic
              { 'Authorization' => "Basic #{Base64.strict_encode64("#{context.api_key}:#{context.api_secret}")}" }
            when :oauth2
              { 'Authorization' => "Bearer #{access_token}" }
            else
              { 'Authorization' => "Bearer #{context.api_key}" }
            end
          end

          # Client-credentials flow for vendors that need it. Cached so a polling
          # job does not re-authenticate on every call.
          def access_token
            token_url = setting(:token_url)
            return context.api_key.to_s if token_url.blank?

            context.cached("#{key}_token", 'access') do
              body = context.http.post_json(
                token_url,
                payload: { grant_type: 'client_credentials' },
                headers: {
                  'Authorization' =>
                    "Basic #{Base64.strict_encode64("#{context.api_key}:#{context.api_secret}")}"
                },
                provider_key: key
              )
              body&.dig('access_token')
            end
          end

          def request_assessment(subject)
            path = setting(:assessment_path)
            return nil if path.blank?

            context.cached(key, subject.cache_fingerprint) do
              context.http.get_json(
                "#{base_url}#{path}",
                params: assessment_params(subject),
                headers: auth_headers,
                provider_key: key
              )
            end
          end

          def request_events(since)
            path = setting(:events_path)
            return nil if path.blank?

            context.http.get_json(
              "#{base_url}#{path}",
              params: { from: since.utc.iso8601, limit: 200 },
              headers: auth_headers,
              provider_key: key
            )
          end

          # Default query contract. Vendors needing a different shape override
          # `assessment_params` in their own file.
          def assessment_params(subject)
            {
              supplierName: subject.supplier_name,
              country: subject.origin_country,
              hsCode: subject.hs_code,
              transportMode: subject.transport_mode,
              route: subject.shipping_route
            }.compact
          end

          # --- response mapping -------------------------------------------------

          def extract_score(payload)
            raw = pointer(payload, mapping['riskScore'])
            return nil if raw.nil?

            return raw.to_i.clamp(0, 100) if raw.is_a?(Numeric) || raw.to_s.match?(/\A\d+(\.\d+)?\z/)

            # A vendor that answers with a label instead of a number.
            LEVEL_TO_SCORE[raw.to_s.downcase]
          end

          def extract_dimensions(payload)
            raw = pointer(payload, mapping['dimensions'])
            return {} unless raw.is_a?(Hash)

            raw.each_with_object({}) do |(dimension, value), memo|
              dimension_key = dimension.to_s.downcase
              next unless Domain::RiskAssessment::DIMENSION_KEYS.include?(dimension_key)

              memo[dimension_key] = normalise_dimension(value)
            end
          end

          def extract_integer(payload, name)
            value = pointer(payload, mapping[name])
            value.nil? ? nil : value.to_i
          end

          def extract_string(payload, name)
            value = pointer(payload, mapping[name])
            value.nil? ? nil : value.to_s.truncate(500)
          end

          # A vendor may report a 0-1 factor, a 0-5 rating or a 0-100 score.
          def normalise_dimension(value)
            numeric = value.to_f
            return numeric.round.clamp(0, 100) if numeric > 5

            (numeric <= 1 ? numeric * 100 : numeric * 20).round.clamp(0, 100)
          end

          def default_reason(payload)
            entity = pointer(payload, mapping['entityId'])
            "#{self.class.descriptor.name}-Bewertung#{entity.present? ? " für #{entity}" : ''}"
          end

          EVENT_TYPE_MAP = {
            'weather' => 'weather', 'natural' => 'disaster', 'disaster' => 'disaster',
            'sanction' => 'sanction', 'sanctions' => 'sanction', 'compliance' => 'sanction',
            'port' => 'port_congestion', 'congestion' => 'port_congestion',
            'labor' => 'supplier', 'labour' => 'supplier', 'supplier' => 'supplier',
            'customs' => 'customs', 'price' => 'price_spike'
          }.freeze

          SEVERITY_MAP = {
            'low' => 'low', 'minor' => 'low', 'medium' => 'medium', 'moderate' => 'medium',
            'high' => 'high', 'severe' => 'high', 'critical' => 'critical', 'extreme' => 'critical'
          }.freeze

          def build_event(entry, since)
            occurred = parse_time(
              pointer(entry, '/occurredAt') || pointer(entry, '/date') || pointer(entry, '/createdAt')
            )
            return nil if occurred.nil? || occurred < since

            Domain::EventDraft.build(
              source: key,
              source_event_id: pointer(entry, '/id') || pointer(entry, '/eventId'),
              event_type: EVENT_TYPE_MAP.fetch(pointer(entry, '/type').to_s.downcase, 'manual'),
              severity: SEVERITY_MAP.fetch(pointer(entry, '/severity').to_s.downcase, 'medium'),
              title: (pointer(entry, '/title') || pointer(entry, '/name') ||
                      "#{self.class.descriptor.name}-Ereignis").to_s.truncate(300),
              description: pointer(entry, '/description')&.to_s&.truncate(1000),
              country_code: FreeData::Support.country_code(pointer(entry, '/country')),
              occurred_at: occurred,
              metadata: { vendor: key, raw: redact(entry) }
            )
          end

          # --- helpers ----------------------------------------------------------

          # Minimal JSON Pointer implementation (RFC 6901) - avoids a dependency
          # for a handful of lookups.
          def pointer(payload, path)
            return nil if payload.nil? || path.blank?

            path.to_s.split('/').reject(&:empty?).reduce(payload) do |node, segment|
              break nil if node.nil?

              key = segment.gsub('~1', '/').gsub('~0', '~')
              case node
              when Hash then node[key] || node[key.to_sym]
              when Array then node[key.to_i]
              end
            end
          end

          def stringify(hash)
            (hash || {}).each_with_object({}) { |(key, value), memo| memo[key.to_s] = value }
          end

          def parse_time(value)
            return nil if value.blank?

            Time.zone.parse(value.to_s)
          rescue ArgumentError, TypeError
            value.to_s.match?(/\A\d+\z/) ? Time.zone.at(value.to_i) : nil
          end

          # Strips anything credential-shaped before it is persisted in
          # `risk_assessments.raw_payload`.
          def redact(payload)
            return nil if payload.nil?

            case payload
            when Hash
              payload.each_with_object({}) do |(key, value), memo|
                memo[key] =
                  if key.to_s.match?(/token|secret|password|api_?key|authorization/i)
                    '***'
                  else
                    redact(value)
                  end
              end
            when Array then payload.map { |entry| redact(entry) }
            else payload
            end
          end

          def not_configured
            context.log(:info, "#{key}: kein API-Key hinterlegt - Provider wird übersprungen")
            nil
          end
        end
      end
    end
  end
end