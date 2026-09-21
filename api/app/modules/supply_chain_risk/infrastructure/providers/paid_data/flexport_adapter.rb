module SupplyChainRisk
  module Infrastructure
    module Providers
      module PaidData
        # Flexport adapter.
        #
        # Speditionssichtbarkeit, Zollstatus und Landed-Cost-Schaetzung.
        #
        # Endpoint and field mapping are contract specific. Confirm them against the
        # signed API documentation; if they differ, override them per project via
        # POST /api/v1/risk_providers/flexport/configure using
        # config.baseUrl / config.assessmentPath / config.mapping.* instead of
        # editing this file.
        class FlexportAdapter < BaseAdapter
          class << self
            def profile
              {
                key: 'flexport',
                base_url: 'https://api.flexport.com',
                assessment_path: '/shipments',
                events_path: '/events',
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