module SupplyChainRisk
  module Infrastructure
    module Providers
      module Internal
        # The manual fallback.
        #
        # Returns the traffic light a specialist maintained by hand (grün / gelb /
        # rot). This is the declared "Surviving fallback" of the module: even with
        # no external data at all, a buyer can express "I know this part is
        # critical" and the price calculation reacts to it.
        #
        # Because a human opinion is not a measurement, `confidence` is capped at
        # 0.8 - high enough to be used when nothing else exists, but an automatic
        # provider with real data still takes precedence in the aggregation.
        class ManualProvider < Domain::RiskDataProvider
          CONFIDENCE = BigDecimal('0.8')

          LEVEL_SCORES = { 'green' => 15, 'yellow' => 50, 'red' => 85 }.freeze

          LEVEL_DIMENSIONS = {
            'green' => { 'operational' => 15 },
            'yellow' => { 'operational' => 50 },
            'red' => { 'operational' => 85, 'geopolitical' => 60 }
          }.freeze

          class << self
            def descriptor
              @descriptor ||= Infrastructure::ProviderCatalogue.find!('manual')
            end
          end

          def assess(subject)
            level = subject.manual_level.to_s
            return nil if LEVEL_SCORES.key?(level) == false

            score = LEVEL_SCORES.fetch(level)

            draft(
              risk_score: score,
              dimensions: LEVEL_DIMENSIONS.fetch(level),
              reason: reason_for(level, subject.manual_note),
              data_sources: ['Manuelle Risikobewertung'],
              confidence: CONFIDENCE,
              # A manual assessment has no expiry - it is valid until a human
              # changes it, so it never "stales" into a green light.
              expires_in: nil
            )
          end

          private

          def reason_for(level, note)
            label = { 'green' => 'grün (unkritisch)', 'yellow' => 'gelb (beobachten)',
                      'red' => 'rot (kritisch)' }.fetch(level)
            note.present? ? "Manuell bewertet als #{label}: #{note}" : "Manuell bewertet als #{label}"
          end
        end
      end
    end
  end
end