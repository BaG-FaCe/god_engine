# frozen_string_literal: true

# Switches every ActiveRecord connection to the configured SQL backend when one
# is stored, so a restart transparently picks up the first-run setup.
#
# Four logical databases are connected: the primary `productdata` plus the
# `users` / `events` / `logs` pools owned by UsersRecord / EventsRecord /
# LogsRecord. On any error the boot keeps the previous (SQLite) connection
# rather than crashing, so a broken configuration can be repaired through the
# setup screen; the API refuses persistent operations until setup succeeds.
#
# App constants are referenced inside `after_initialize` because Zeitwerk is not
# yet ready when the initializer file itself is loaded (same convention as
# config/initializers/background_jobs.rb).
Rails.application.config.after_initialize do
  next unless DatabaseSetup::Runtime.sql_backend?

  configuration = DatabaseSetup::ConfigurationStore.load

  if configuration
    begin
      DatabaseSetup::Runtime.establish_connections!(configuration)
      Rails.logger.info(
        "DatabaseSetup: connections switched to #{configuration.adapter} " \
        "(#{configuration.host}; #{configuration.database_names.join(', ')})"
      )
    rescue StandardError => e
      message = e.message.to_s
      message = message.gsub(configuration.password, '***') if configuration.password.present?
      Rails.logger.error("DatabaseSetup: could not connect to #{configuration.adapter} (#{configuration.host}): #{e.class} - #{message}")
    end
  end
end


