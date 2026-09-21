module SupplyChainRisk
  module Infrastructure
    module Providers
      module PaidData
        # ONESOURCE Global Trade adapter.
        #
        # Denied-Party-Screening und globale Trade-Inhalte.
        #
        # Endpoint and field mapping are contract specific. Confirm them against the
        # signed API documentation; if they differ, override them per project via
        # POST /api/v1/risk_providers/oneclear/configure using
        # config.baseUrl / config.assessmentPath / config.mapping.* instead of
        # editing this file.
        class OneClearAdapter < BaseAdapter
          class << self
            def profile
              {
                key: 'oneclear',
                base_url: 'https://api.thomsonreuters.com',
                assessment_path: '/v1/globaltrade/screening',
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