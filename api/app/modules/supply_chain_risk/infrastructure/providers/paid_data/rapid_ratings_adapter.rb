module SupplyChainRisk
  module Infrastructure
    module Providers
      module PaidData
        # RapidRatings adapter.
        #
        # Financial Health Scores fuer private und oeffentliche Lieferanten.
        #
        # Endpoint and field mapping are contract specific. Confirm them against the
        # signed API documentation; if they differ, override them per project via
        # POST /api/v1/risk_providers/rapid_ratings/configure using
        # config.baseUrl / config.assessmentPath / config.mapping.* instead of
        # editing this file.
        class RapidRatingsAdapter < BaseAdapter
          class << self
            def profile
              {
                key: 'rapid_ratings',
                base_url: 'https://api.rapidratings.com',
                assessment_path: '/v1/companies/fhr',
                events_path: '/v1/events',
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