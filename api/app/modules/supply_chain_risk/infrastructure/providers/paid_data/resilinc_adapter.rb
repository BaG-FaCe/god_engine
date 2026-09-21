module SupplyChainRisk
  module Infrastructure
    module Providers
      module PaidData
        # Resilinc adapter.
        #
        # Multi-Tier-Lieferantenmapping und ereignisbasierte Alarme.
        #
        # Endpoint and field mapping are contract specific. Confirm them against the
        # signed API documentation; if they differ, override them per project via
        # POST /api/v1/risk_providers/resilinc/configure using
        # config.baseUrl / config.assessmentPath / config.mapping.* instead of
        # editing this file.
        class ResilincAdapter < BaseAdapter
          class << self
            def profile
              {
                key: 'resilinc',
                base_url: 'https://api.resilinc.com',
                assessment_path: '/v2/events/supplier',
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