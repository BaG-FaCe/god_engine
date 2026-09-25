# Boots the Rails application for the suite.
#
# Everything environment specific lives here: transaction rollback, WebMock (no
# outbound socket ever opens) and the shared example groups under `spec/support`.
ENV['RAILS_ENV'] ||= 'test'
require 'spec_helper'
ENV['AR_ENCRYPTION_PRIMARY_KEY'] ||= 'god-engine-test-primary-key'
ENV['AR_ENCRYPTION_DETERMINISTIC_KEY'] ||= 'god-engine-test-deterministic-key'
ENV['AR_ENCRYPTION_KEY_DERIVATION_SALT'] ||= 'god-engine-test-key-derivation-salt'

require File.expand_path('../config/environment', __dir__)
require 'rspec/rails'
require 'webmock/rspec'
require 'active_support/testing/time_helpers'

abort('The Rails environment is running in production mode!') if Rails.env.production?

ActiveRecord::Migration.maintain_test_schema!

Dir[Rails.root.join('spec/support/**/*.rb')].sort.each { |file| require file }

RSpec.configure do |config|
  config.fixture_paths = [Rails.root.join('spec/fixtures')]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.example_status_persistence_file_path = 'tmp/rspec-status.txt'
  config.include FactoryBot::Syntax::Methods
  config.include ActiveSupport::Testing::TimeHelpers
end
       