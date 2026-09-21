module SupplyChainRisk
  module Infrastructure
    module Providers
      module PaidData
        # Prewave adapter.
        #
        # ESG-, Menschenrechts- und Compliance-Alerts (LkSG-tauglich).
        #
        # Endpoint and field mapping are contract specific. Confirm them against the
        # signed API documentation; if they differ, override them per project via
        # POST /api/v1/risk_providers/prewave/configure using
        # config.baseUrl / config.assessmentPath / config.mapping.* instead of
        # editing this file.
        class PrewaveAdapter < BaseAdapter
          class << self
            def profile
              {
                key: 'prewave',
                base_url: 'https://api.prewave.com',
                assessment_path: '/v2/alerts/supplier',
                events_path: '/v2/alerts',
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