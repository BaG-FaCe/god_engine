module SupplyChainRisk
  module Infrastructure
    module Providers
      module PaidData
        # FourKites adapter.
        #
        # Sichtbarkeit mit Standzeiten, Detention und Lane-Analytics.
        #
        # Endpoint and field mapping are contract specific. Confirm them against the
        # signed API documentation; if they differ, override them per project via
        # POST /api/v1/risk_providers/fourkites/configure using
        # config.baseUrl / config.assessmentPath / config.mapping.* instead of
        # editing this file.
        class FourkitesAdapter < BaseAdapter
          class << self
            def profile
              {
                key: 'fourkites',
                base_url: 'https://api.fourkites.com',
                assessment_path: '/api/v1/shipments/insights',
                events_path: '/api/v1/alerts',
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