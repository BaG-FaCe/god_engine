Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true

  config.consider_all_requests_local = false

  # ---------------------------------------------------------------------
  # Caching - Solid Cache (SQLite backed, no Redis)
  # ---------------------------------------------------------------------
  config.action_controller.perform_caching = true
  config.cache_store = :solid_cache_store

  # ---------------------------------------------------------------------
  # Background jobs - Solid Queue (SQLite backed, no Sidekiq/Redis)
  # ---------------------------------------------------------------------
  # Solid Queue needs `fork`, which Windows does not provide. On Windows set
  # BACKGROUND_JOB_ADAPTER=async to run jobs in a Puma thread; on Linux/macOS
  # run `bin/jobs` (or SOLID_QUEUE_IN_PUMA=true) as documented in
  # docs/15-deployment.md.
  config.active_job.queue_adapter = ENV.fetch('BACKGROUND_JOB_ADAPTER', 'solid_queue').to_sym

  # Log to STDOUT so the process can be supervised by any init system.
  config.logger = ActiveSupport::TaggedLogging.logger($stdout)
  config.log_level = ENV.fetch('RAILS_LOG_LEVEL', 'info')
  config.log_tags = [:request_id]

  config.action_mailer.perform_caching = false
  config.action_mailer.raise_delivery_errors = true

  config.i18n.fallbacks = true

  # Assume a TLS terminating reverse proxy in front of Puma.
  config.assume_ssl = true
  config.force_ssl = ENV.fetch('FORCE_SSL', 'true') == 'true'

  config.active_support.report_deprecations = false

  # Keep only the last 1000 log entries in the local log file.
  config.log_file_size = 100 * 1024 * 1024

  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [:id]

  # Skip DNS rebinding protection for health check requests.
  config.host_authorization = { exclude: ->(request) { request.path == '/up' } }
end