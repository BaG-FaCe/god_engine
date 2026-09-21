module SupplyChainRisk
  module Infrastructure
    module Providers
      module PaidData
        # Interos adapter.
        #
        # KI-basiertes Multi-Tier-Risiko- und Resilienz-Scoring.
        #
        # Endpoint and field mapping are contract specific. Confirm them against the
        # signed API documentation; if they differ, override them per project via
        # POST /api/v1/risk_providers/interos/configure using
        # config.baseUrl / config.assessmentPath / config.mapping.* instead of
        # editing this file.
        class InterosAdapter < BaseAdapter
          class << self
            def profile
              {
                key: 'interos',
                base_url: 'https://api.interos.ai',
                assessment_path: '/v1/suppliers/risk',
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