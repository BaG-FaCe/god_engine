module Api
  module V1
    class HealthController < ApplicationController
      # GET /api/v1/health — never throttled (see rack_attack.rb).
      def show
        db_ok = begin
          ActiveRecord::Base.connection.execute('SELECT 1')
          true
        rescue StandardError
          false
        end
        caps = Shared::Infrastructure::Jobs::JobAdapter.capabilities
        render json: {
          status: db_ok ? 'ok' : 'degraded',
          time: Time.current.iso8601,
          database: db_ok ? 'ok' : 'error',
          jobs: { adapter: caps.adapter.to_s, durable: caps.durable, scheduler: caps.scheduler },
          cache: { store: 'solid_cache' },
          providers: { total: SupplyChainRisk::Infrastructure::ProviderCatalogue.keys.size }
        }
      end
    end
  end
end
