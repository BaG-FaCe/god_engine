Rails.application.configure do
  # Reload code on every request so the modular contexts stay fast to iterate on.
  config.enable_reloading = true
  config.eager_load = false

  # Full error reports are useful while developing.
  config.consider_all_requests_local = true

  # ---------------------------------------------------------------------
  # Caching
  # ---------------------------------------------------------------------
  # `perform_caching` only controls HTTP level caching (ETag / expires_in).
  # Provider responses are cached explicitly through `Rails.cache`, which is
  # backed by Solid Cache - that is what protects the external API rate limits
  # during development as well.
  config.action_controller.perform_caching = false
  config.cache_store = :solid_cache_store

  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.delivery_method = :test
  config.action_mailer.perform_caching = false

  config.active_support.deprecation = :log
  config.active_support.disallowed_deprecation = :raise
  config.active_support.disallowed_deprecation_warnings = []

  config.active_record.migration_error = :page_load
  config.active_record.verbose_query_logs = true
  config.active_record.query_log_tags_enabled = true
  config.active_record.query_log_tags = [
    :controller,
    :action,
    :job,
    :source_location,
  ]

  # Highlight code that enqueued a background job in the logs.
  config.active_job.verbose_enqueue_logs = true

  config.i18n.raise_on_missing_translations = true

  # Allow the Vite dev server (localhost / LAN) to reach the API.
  config.hosts.clear

  # Raises helpful errors when a generator leaves incomplete files behind.
  config.generators.apply_rubocop_autocorrect_after_generate!
end