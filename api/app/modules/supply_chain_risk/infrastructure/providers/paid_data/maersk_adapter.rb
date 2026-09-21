module SupplyChainRisk
  module Infrastructure
    module Providers
      module PaidData
        # Maersk adapter.
        #
        # Ocean-Fahrplan, Container-Tracking und Port-Call-Zuverlaessigkeit.
        #
        # Endpoint and field mapping are contract specific. Confirm them against the
        # signed API documentation; if they differ, override them per project via
        # POST /api/v1/risk_providers/maersk/configure using
        # config.baseUrl / config.assessmentPath / config.mapping.* instead of
        # editing this file.
        class MaerskAdapter < BaseAdapter
          class << self
            def profile
              {
                key: 'maersk',
                base_url: 'https://api.maersk.com',
                assessment_path: '/track-and-trace/api/v1/events',
                events_path: '/track-and-trace/api/v1/events',
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