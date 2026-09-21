module SupplyChainRisk
  module Infrastructure
    module Providers
      module PaidData
        # Shippeo adapter.
        #
        # Europaeische Road- und Rail-Sichtbarkeit mit ETA-Prognose.
        #
        # Endpoint and field mapping are contract specific. Confirm them against the
        # signed API documentation; if they differ, override them per project via
        # POST /api/v1/risk_providers/shippeo/configure using
        # config.baseUrl / config.assessmentPath / config.mapping.* instead of
        # editing this file.
        class ShippeoAdapter < BaseAdapter
          class << self
            def profile
              {
                key: 'shippeo',
                base_url: 'https://api.shippeo.com',
                assessment_path: '/v2/transports',
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