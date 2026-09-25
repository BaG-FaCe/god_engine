require 'rails_helper'

RSpec.describe SupplyChainRisk::Infrastructure::PollSchedule do
  describe '.scope_for' do
    it 'returns a default scope when no configuration exists' do
      scope = described_class.scope_for('gdacs')

      expect(scope.provider_key).to eq('gdacs')
      expect(scope.config).to be_nil
      expect(scope.interval_minutes).to be > 0
      expect(scope.due?).to be(true)
    end

    it 'honours the per-project poll interval (not due yet -> nil)' do
      create(:risk_provider_config, provider_key: 'gdacs', poll_interval_minutes: 60,
                                    last_run_at: 10.minutes.ago)

      expect(described_class.scope_for('gdacs')).to be_nil
    end

    it 'returns the scope when a configured provider is due' do
      config = create(:risk_provider_config, provider_key: 'gdacs', poll_interval_minutes: 30,
                                             last_run_at: 2.hours.ago)

      scope = described_class.scope_for('gdacs')
      expect(scope.config).to eq(config)
      expect(scope.due?).to be(true)
    end

    it 'returns nil when the provider is disabled for every project' do
      create(:risk_provider_config, provider_key: 'gdacs', enabled: false)

      expect(described_class.scope_for('gdacs')).to be_nil
    end
  end

  describe '.due' do
    it 'returns only the scopes that are enabled and due' do
      create(:risk_provider_config, provider_key: 'gdacs', poll_interval_minutes: 30,
                                    last_run_at: 2.hours.ago)
      create(:risk_provider_config, provider_key: 'usgs_earthquake', enabled: false)

      scopes = described_class.due(provider_keys: %w[gdacs usgs_earthquake])
      expect(scopes.map(&:provider_key)).to eq(%w[gdacs])
    end
  end
end
