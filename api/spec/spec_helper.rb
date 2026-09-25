# RSpec configuration shared by every spec in the suite.
#
# `rails_helper` (not this file) is required by specs that need the application;
# this file only contains the framework-level settings and is kept deliberately
# free of Rails references so it can be required from plain-Ruby specs.
#
# Coverage is opt-in (`COVERAGE=1 bundle exec rspec`) so a normal run stays fast.
if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start 'rails' do
    enable_coverage :branch
    add_filter %w[/spec/ /config/ /db/]
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  # The suite is run both standalone and from a CI matrix; the profile is only
  # useful when a single file is being debugged.
  config.default_formatter = 'doc' if config.files_to_run.one?
  config.profile_examples = 10
end
