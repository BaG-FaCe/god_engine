module SupplyChainRisk
  module Infrastructure
    module Providers
      module PaidData
        # Descartes adapter.
        #
        # Restricted-Party-Screening und Trade-Compliance-Inhalte.
        #
        # Endpoint and field mapping are contract specific. Confirm them against the
        # signed API documentation; if they differ, override them per project via
        # POST /api/v1/risk_providers/descartes/configure using
        # config.baseUrl / config.assessmentPath / config.mapping.* instead of
        # editing this file.
        class DescartesAdapter < BaseAdapter
          class << self
            def profile
              {
                key: 'descartes',
                base_url: 'https://api.descartes.com',
                assessment_path: '/v1/screening',
                events_path: '/v1/events',
                auth: :api_key_header,
                token_url: ''
              }.freeze
            end
          end
        end
      end
    end
  end
end