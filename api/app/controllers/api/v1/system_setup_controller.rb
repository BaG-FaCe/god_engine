# frozen_string_literal: true

module Api
  module V1
    # First-run SQL Server setup.
    #
    # The platform runs on SQLite out of the box; this controller lets an
    # operator point it at a Microsoft SQL Server during first-run setup. It is
    # intentionally free of authentication (there are no users yet) but is
    # locked once a configuration has been saved so it cannot be abused to
    # re-configure or probe an already-provisioned instance.
    #
    # The supplied password is never echoed: responses use the redacted
    # configuration and every adapter error is sanitised before rendering.
    class SystemSetupController < ApplicationController
      # The setup endpoints are the only ones that must work before the SQL
      # backend has been configured.
      skip_before_action :ensure_persistence_ready!

      rescue_from DatabaseSetup::Connection::Error,
                  DatabaseSetup::Provisioner::Error,
                  DatabaseSetup::Client::Error, with: :render_connection_error

      class AlreadyConfigured < StandardError; end
      rescue_from AlreadyConfigured, with: :render_already_configured

      # GET /api/v1/system/setup/status
      def status
        render json: {
          adapter: DatabaseSetup::Runtime.adapter_name,
          adapters: DatabaseSetup::Configuration::ADAPTERS,
          sqlServerConfigured: DatabaseSetup::ConfigurationStore.configured?,
          setupRequired: DatabaseSetup::Runtime.setup_required?,
          databases: DatabaseSetup::Configuration::REQUIRED_DATABASES
        }
      end

      # POST /api/v1/system/setup/test — verify connectivity + authentication,
      # and report which required databases already exist (read-only).
      def test
        ensure_setup_allowed!
        @configuration = build_configuration

        render json: DatabaseSetup::Connection.test!(@configuration).merge(
          databases: probe_databases(@configuration)
        )
      end

      # POST /api/v1/system/setup/complete — provision, migrate and persist the
      # configuration. After this the application operates on SQL Server.
      def complete
        ensure_setup_allowed!
        @configuration = build_configuration

        result = DatabaseSetup::Bootstrap.call(@configuration)
        DatabaseSetup::ConfigurationStore.save(@configuration)
        DatabaseSetup::Runtime.establish_connections!(@configuration)

        render json: {
          configured: true,
          adapter: @configuration.adapter,
          configuration: @configuration.redacted,
          provisioned: result[:provisioned],
          schema: result[:schema],
          imported: result[:imported],
          seeded: result[:seeded],
          verification: result[:verification],
          migrationRun: result[:migration_run]
        }
      rescue DatabaseSetup::Verification::Error => e
        render_error(
          "Migration verification failed: #{sanitize(e.message)}",
          code: 'migration_verification_failed', status: :bad_gateway
        )
      rescue ArgumentError => e
        render_error(e.message, code: 'invalid_configuration', status: :unprocessable_entity)
      rescue StandardError => e
        render_connection_error(e)
      end

      private

      def build_configuration
        DatabaseSetup::Configuration.new(
          adapter: params[:adapter].presence || 'sqlserver',
          host: params[:server],
          port: params[:port].presence,
          username: params[:username],
          password: params[:password],
          database: params[:database].presence || 'productdata',
          users_database: params[:usersDatabase].presence || 'users',
          events_database: params[:eventsDatabase].presence || 'events',
          logs_database: params[:logsDatabase].presence || 'logs',
          encrypt: params[:encrypt] != false,
          timeout: params[:timeout].presence || 15
        )
      end

      def ensure_setup_allowed!
        raise AlreadyConfigured if DatabaseSetup::ConfigurationStore.configured?
      end

      def probe_databases(configuration)
        existing = DatabaseSetup::Connection.databases(configuration)
        required = configuration.database_names
        {
          existing: existing & required,
          missing: required - existing
        }
      end

      def render_connection_error(exception)
        render_error(
          "#{adapter_label}-Verbindung fehlgeschlagen: #{sanitize(exception.message)}",
          code: 'sql_server_connection_error', status: :bad_gateway
        )
      end

      def render_already_configured(_exception)
        render_error(
          'Das SQL-Backend ist bereits konfiguriert. Eine erneute Einrichtung ist nicht zulässig.',
          code: 'already_configured', status: :conflict
        )
      end

      def adapter_label
        @configuration ? @configuration.adapter : 'SQL'
      end

      # Belt and braces: no response may ever contain the supplied password.
      def sanitize(message)
        text = message.to_s
        password = @configuration&.password
        return text if password.blank?

        text.gsub(password, '***')
      end
    end
  end
end
