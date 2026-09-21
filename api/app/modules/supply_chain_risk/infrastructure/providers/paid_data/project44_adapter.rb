module SupplyChainRisk
  module Infrastructure
    module Providers
      module PaidData
        # project44 adapter.
        #
        # Real-time multimodale Sichtbarkeit auf Sendungs- und Lane-Ebene.
        #
        # Endpoint and field mapping are contract specific. Confirm them against the
        # signed API documentation; if they differ, override them per project via
        # POST /api/v1/risk_providers/project44/configure using
        # config.baseUrl / config.assessmentPath / config.mapping.* instead of
        # editing this file.
        class Project44Adapter < BaseAdapter
          class << self
            def profile
              {
                key: 'project44',
                base_url: 'https://api.project44.com',
                assessment_path: '/api/v4/shipments/insights',
                events_path: '/api/v4/alerts',
                auth: :oauth2,
                token_url: 'https://api.project44.com/api/v4/oauth2/token'
              }.freeze
            end
          end
        end
      end
    end
  end
end