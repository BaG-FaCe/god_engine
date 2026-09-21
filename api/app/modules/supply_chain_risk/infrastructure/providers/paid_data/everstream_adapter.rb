module SupplyChainRisk
  module Infrastructure
    module Providers
      module PaidData
        # Everstream Analytics adapter.
        #
        # Praediktive Lieferanten-, Wetter-, Arbeits- und Geopolitik-Risiken.
        #
        # Endpoint and field mapping are contract specific. Confirm them against the
        # signed API documentation; if they differ, override them per project via
        # POST /api/v1/risk_providers/everstream/configure using
        # config.baseUrl / config.assessmentPath / config.mapping.* instead of
        # editing this file.
        class EverstreamAdapter < BaseAdapter
          class << self
            def profile
              {
                key: 'everstream',
                base_url: 'https://api.everstream.ai',
                assessment_path: '/v1/risk/supplier',
                events_path: '/v1/events',
                auth: :bearer,
                token_url: ''
              }.freeze
            end
          end
        end
      end
    end
  end
end