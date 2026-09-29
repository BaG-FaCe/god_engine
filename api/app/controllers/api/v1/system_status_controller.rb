# frozen_string_literal: true

module Api
  module V1
    # System status & database diagnostics for administrators.
    class SystemStatusController < ApplicationController
      before_action :authenticate_user!
      before_action :require_admin!

      # GET /api/v1/system/status
      def show
        dbs = {
          productdata: check_db_health(ActiveRecord::Base),
          users: check_db_health(UsersRecord),
          events: check_db_health(EventsRecord),
          logs: check_db_health(LogsRecord)
        }

        render json: {
          adapter: DatabaseSetup::Runtime.adapter_name,
          sqlBackend: DatabaseSetup::Runtime.sql_backend?,
          databases: dbs,
          activeUsersCount: User.active.count,
          totalUsersCount: User.count,
          activeSessionsCount: Session.active.count
        }
      end

      private

      def check_db_health(model_class)
        model_class.connection.execute('SELECT 1')
        'connected'
      rescue StandardError => e
        "error: #{e.class}"
      end
    end
  end
end
