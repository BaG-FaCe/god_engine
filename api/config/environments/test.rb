Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = ENV['CI'].present?

  # Jobs are run synchronously or via the `:test` adapter so request specs can
  # assert `have_enqueued_job` deterministically. `JobAdapter.install!` (see
  # config/initializers/background_jobs.rb) skips test to respect this.
  config.active_job.queue_adapter = :test

  # Keep the suite fast and isolated: the in-process memory store is used
  # instead of Solid Cache. `spec/integration/solid_infrastructure_spec.rb`
  # verifies that the Solid Cache / Solid Queue setup itself is intact.
  config.cache_store = :memory_store

  config.active_support.deprecation = :stderr
  config.active_support.disallowed_deprecation = :raise
  config.active_support.disallowed_deprecation_warnings = []

  config.action_mailer.delivery_method = :test

  config.i18n.raise_on_missing_translations = true

  # Outbound HTTP is stubbed in tests through WebMock / VCR.
  config.hosts.clear
end