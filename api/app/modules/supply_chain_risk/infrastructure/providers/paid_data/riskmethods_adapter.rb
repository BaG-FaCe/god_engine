module SupplyChainRisk
  module Infrastructure
    module Providers
      module PaidData
        # riskmethods adapter.
        #
        # Supplier-Risk-Scoring, Early-Warning-Radar und Compliance.
        #
        # Endpoint and field mapping are contract specific. Confirm them against the
        # signed API documentation; if they differ, override them per project via
        # POST /api/v1/risk_providers/riskmethods/configure using
        # config.baseUrl / config.assessmentPath / config.mapping.* instead of
        # editing this file.
        class RiskmethodsAdapter < BaseAdapter
          class << self
            def profile
              {
                key: 'riskmethods',
                base_url: 'https://api.riskmethods.net',
                assessment_path: '/v2/suppliers/risk',
                events_path: '/v2/early-warning',
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