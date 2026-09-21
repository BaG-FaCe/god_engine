module SupplyChainRisk
  module Infrastructure
    module Providers
      module PaidData
        # Vizion adapter.
        #
        # Container-Tracking fuer alle grossen Ocean-Carrier.
        #
        # Endpoint and field mapping are contract specific. Confirm them against the
        # signed API documentation; if they differ, override them per project via
        # POST /api/v1/risk_providers/vizion/configure using
        # config.baseUrl / config.assessmentPath / config.mapping.* instead of
        # editing this file.
        class VizionAdapter < BaseAdapter
          class << self
            def profile
              {
                key: 'vizion',
                base_url: 'https://api.vizionapi.com',
                assessment_path: '/v2/containers',
                events_path: '/v2/events',
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