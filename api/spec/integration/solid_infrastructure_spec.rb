require 'rails_helper'

# Verifies the Solid Cache / Solid Queue wiring itself is intact, as noted in
# config/environments/test.rb. The suite runs with the in-memory cache and the
# `:test` job adapter for speed; this spec asserts the production adapters are
# still configured and resolve correctly, so the "Solid statt Redis" correction
# (Update-Prompt Infrastruktur) cannot silently regress.
RSpec.describe 'Solid Cache / Solid Queue infrastructure' do
  it 'configures Solid Cache as the cache store in production' do
    source = File.read(Rails.root.join('config/application.rb'))
    expect(source).to match(/config\.cache_store\s*=\s*:solid_cache_store/)
  end

  it 'routes cache and queue to their own SQLite databases' do
    expect(Rails.application.config.solid_cache.connects_to).to be_present
    expect(Rails.application.config.solid_queue.connects_to).to be_present
  end

  it 'declares Solid Queue and Solid Cache in the Gemfile (no Redis)' do
    gemfile = File.read(Rails.root.join('Gemfile'))
    expect(gemfile).to include("gem 'solid_cache'")
    expect(gemfile).to include("gem 'solid_queue'")
    expect(gemfile).not_to match(/gem ['"]redis/)
  end
end
