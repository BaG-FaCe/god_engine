require_relative 'boot'

require 'rails'
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_mailer/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module GodEngine
  # Modular monolith host application.
  #
  # Every bounded context lives below `app/modules/<context>` and is wired into
  # the host through explicit configuration in `config/initializers` and
  # `config/routes.rb` - never through implicit global references. That is what
  # keeps the contexts extractable into services later on.
  class Application < Rails::Application
    config.load_defaults 8.0

    # API-only: no asset pipeline, no view helpers, no cookies required for the
    # JSON endpoints (the SPA authenticates with a bearer token).
    config.api_only = true

    # ---------------------------------------------------------------------
    # Zeitwerk / autoloading
    # ---------------------------------------------------------------------
    # `app/modules` holds the bounded contexts. Each context directory is an
    # implicit namespace (`Calculator`, `SupplyChainRisk`, `Shared`, ...).
    config.autoload_paths += %w[app/modules].map { |p| Rails.root.join(p).to_s }
    config.eager_load_paths += %w[app/modules].map { |p| Rails.root.join(p).to_s }

    # Background jobs and serializers live in conventional directories.
    config.autoload_paths << Rails.root.join('lib').to_s
    config.eager_load_paths << Rails.root.join('lib').to_s

    # ---------------------------------------------------------------------
    # Locale / time zone
    # ---------------------------------------------------------------------
    config.i18n.default_locale = :de
    config.i18n.available_locales = %i[de en]
    config.i18n.fallbacks = [:de]
    config.time_zone = 'Berlin'
    config.active_record.default_timezone = :utc

    # Money is transported as integer cents; percentages as decimal fractions.
    config.active_record.schema_format = :ruby

    # ---------------------------------------------------------------------
    # Infrastructure adapters
    # ---------------------------------------------------------------------
    # Cache: Solid Cache (SQLite). Jobs: resolved per platform in
    # `config/initializers/background_jobs.rb` because Solid Queue needs `fork`.
    config.cache_store = :solid_cache_store

    # Solid Cache / Solid Queue keep their data in their own SQLite files.
    config.solid_cache.connects_to = { database: { writing: :cache } }
    config.solid_queue.connects_to = { database: { writing: :queue } }

    # ---------------------------------------------------------------------
    # Security
    # ---------------------------------------------------------------------
    config.filter_parameters += %i[
      password password_confirmation token api_key api_key_encrypted
      secret client_secret authorization
    ]

    # Encrypt provider API keys at rest with ActiveRecord::Encryption.
    config.active_record.encryption.primary_key =
      ENV['AR_ENCRYPTION_PRIMARY_KEY'] || 'god-engine-development-primary-key'
    config.active_record.encryption.deterministic_key =
      ENV['AR_ENCRYPTION_DETERMINISTIC_KEY'] || 'god-engine-development-deterministic-key'
    config.active_record.encryption.key_derivation_salt =
      ENV['AR_ENCRYPTION_KEY_DERIVATION_SALT'] || 'god-engine-development-key-derivation-salt'
    config.active_record.encryption.support_unencrypted_data = !Rails.env.production?

    # ---------------------------------------------------------------------
    # Generators
    # ---------------------------------------------------------------------
    config.generators do |g|
      g.test_framework :rspec, fixture: false
      g.factory_bot false
      g.helper false
      g.assets false
    end
  end
end