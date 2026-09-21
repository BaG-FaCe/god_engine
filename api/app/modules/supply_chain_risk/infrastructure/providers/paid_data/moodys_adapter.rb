module SupplyChainRisk
  module Infrastructure
    module Providers
      module PaidData
        # Moody's adapter.
        #
        # Ratings und Ausfallwahrscheinlichkeiten grosser Lieferanten.
        #
        # Endpoint and field mapping are contract specific. Confirm them against the
        # signed API documentation; if they differ, override them per project via
        # POST /api/v1/risk_providers/moodys/configure using
        # config.baseUrl / config.assessmentPath / config.mapping.* instead of
        # editing this file.
        class MoodysAdapter < BaseAdapter
          class << self
            def profile
              {
                key: 'moodys',
                base_url: 'https://api.moodys.com',
                assessment_path: '/v1/ratings',
                events_path: '/v1/events',
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