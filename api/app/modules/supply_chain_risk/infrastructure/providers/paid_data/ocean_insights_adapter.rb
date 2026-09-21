module SupplyChainRisk
  module Infrastructure
    module Providers
      module PaidData
        # Ocean Insights adapter.
        #
        # Fahrplanzuverlaessigkeit, Blank Sailings und Rollover-Raten.
        #
        # Endpoint and field mapping are contract specific. Confirm them against the
        # signed API documentation; if they differ, override them per project via
        # POST /api/v1/risk_providers/ocean_insights/configure using
        # config.baseUrl / config.assessmentPath / config.mapping.* instead of
        # editing this file.
        class OceanInsightsAdapter < BaseAdapter
          class << self
            def profile
              {
                key: 'ocean_insights',
                base_url: 'https://api.ocean-insights.com',
                assessment_path: '/v1/reliability',
                events_path: '/v1/alerts',
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