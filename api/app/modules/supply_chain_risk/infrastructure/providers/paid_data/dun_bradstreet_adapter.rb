module SupplyChainRisk
  module Infrastructure
    module Providers
      module PaidData
        # Dun & Bradstreet adapter.
        #
        # D-U-N-S-Firmographics, Finanzstaerke und Insolvenzrisiko.
        #
        # Endpoint and field mapping are contract specific. Confirm them against the
        # signed API documentation; if they differ, override them per project via
        # POST /api/v1/risk_providers/dun_bradstreet/configure using
        # config.baseUrl / config.assessmentPath / config.mapping.* instead of
        # editing this file.
        class DunBradstreetAdapter < BaseAdapter
          class << self
            def profile
              {
                key: 'dun_bradstreet',
                base_url: 'https://plus.dnb.com',
                assessment_path: '/v2/data/duns/company',
                events_path: '/v2/events',
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