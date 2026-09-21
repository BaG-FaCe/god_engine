module SupplyChainRisk
  module Infrastructure
    module Providers
      module FreeData
        # ECB reference exchange rates (via the open Frankfurter API).
        #
        # Currency volatility is a financial risk proxy for cross-border sourcing:
        # a weakening supplier currency erodes agreed margins and pushes prices up
        # at the next contract round.
        class EcbExchangeRateProvider < Domain::RiskDataProvider
          ENDPOINT = 'https://api.frankfurter.dev/v1/latest'
          # Reference date used to measure the move, configurable per deployment.
          DEFAULT_LOOKBACK_DAYS = 90
          STABLE_SCORE = 10

          VOLATILITY_BANDS = [{ min: 0.15, score: 85 }, { min: 0.10, score: 70 },
                              { min: 0.06, score: 50 }, { min: 0.03, score: 30 }].freeze

          NON_EURO = %w[USD GBP CHF PLN CZK HUF SEK NOK DKK TRY CNY JPY KRW INR BRL MXN ZAR].freeze

          class << self
            def descriptor
              @descriptor ||= Infrastructure::ProviderCatalogue.find!('ecb_fx')
            end
          end

          def assess(subject)
            home = subject.destination_country.presence || 'EUR'
            foreign = subject.origin_country.presence
            return nil if foreign.blank? || foreign == home

            currency = currency_for(foreign)
            return nil if currency.nil? || currency == 'EUR'

            change = change_pct(currency)
            return nil if change.nil?

            score = VOLATILITY_BANDS.find { |band| change.abs >= band[:min] }&.fetch(:score) || STABLE_SCORE
            score = (score * 0.7).round if change.negative?

            draft(
              risk_score: score,
              dimensions: { 'financial' => score },
              reason: format('EUR/%s hat sich in %d Tagen um %.1f %% bewegt',
                             currency, lookback_days, change * 100),
              data_sources: ['ECB Referenzkurse'],
              raw_payload: { currency: currency, changePct: change },
              confidence: BigDecimal('0.55')
            )
          end

          private

          def currency_for(country_code)
            return 'USD' if country_code.to_s.upcase == 'US'

            NON_EURO.include?(country_code.to_s.upcase) ? country_code.to_s.upcase : nil
          end

          def change_pct(currency)
            latest = rate(ENDPOINT, { base: 'EUR', symbols: currency })
            past = rate('https://api.frankfurter.dev/v1/%<date>s', { base: 'EUR', symbols: currency },
                        lookback_date)
            return nil if latest.nil? || past.nil? || past.zero?

            (latest - past) / past
          rescue Shared::Infrastructure::Http::JsonClient::Error => e
            context.log(:warn, 'EZB-Kursabfrage fehlgeschlagen', error: e.message)
            nil
          end

          def rate(url, params, extra = nil)
            resolved = extra ? format(url, date: extra) : url
            context.cached('ecb_fx', "#{resolved}:#{params}") do
              body = context.http.get_json(resolved, params: params, provider_key: key)
              body&.dig('rates')&.values&.first
            end
          end

          def lookback_days
            Integer(ENV.fetch('FX_LOOKBACK_DAYS', DEFAULT_LOOKBACK_DAYS))
          end

          def lookback_date
            (Date.current - lookback_days).iso8601
          end
        end
      end
    end
  end
end