module SupplyChainRisk
  module Infrastructure
    module Providers
      module PaidData
        # Amber Road adapter.
        #
        # Global Trade Management: Screening, Tarife und FTA-Inhalte.
        #
        # Endpoint and field mapping are contract specific. Confirm them against the
        # signed API documentation; if they differ, override them per project via
        # POST /api/v1/risk_providers/amber_road/configure using
        # config.baseUrl / config.assessmentPath / config.mapping.* instead of
        # editing this file.
        class AmberRoadAdapter < BaseAdapter
          class << self
            def profile
              {
                key: 'amber_road',
                base_url: 'https://api.e2open.com',
                assessment_path: '/v1/screening',
                events_path: '/v1/events',
                auth: :basic,
                token_url: ''
              }.freeze
            end
          end
        end
      end
    end
  end
end