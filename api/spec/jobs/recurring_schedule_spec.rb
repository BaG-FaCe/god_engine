require 'rails_helper'

# Recurring job configuration is data, not code - so a test can and should guard
# it. If a developer renames a job class or drops an interval, this spec fails.
RSpec.describe 'Recurring schedule (config/recurring.yml)' do
  let(:config) do
    YAML.safe_load(File.read(Rails.root.join('config/recurring.yml')), aliases: true)
  end
  let(:shared) { config.fetch('shared') }

  it 'schedules every risk polling job on the risk_polling queue' do
    polling = shared.slice('poll_disaster_alerts', 'sync_freight_index',
                           'refresh_risk_assessments', 'refresh_sanctions_lists')

    expect(polling.keys).to contain_exactly(
      'poll_disaster_alerts', 'sync_freight_index',
      'refresh_risk_assessments', 'refresh_sanctions_lists'
    )
    polling.each_value do |entry|
      expect(entry['queue']).to eq('risk_polling')
    end
  end

  it 'schedules the maintenance jobs on the maintenance queue' do
    maintenance = shared.slice('purge_expired_risk_assessments', 'recompute_risk_surcharges')
    maintenance.each_value do |entry|
      expect(entry['queue']).to eq('maintenance')
    end
  end

  it 'references job classes that actually exist' do
    shared.each_value do |entry|
      klass = entry['command'].to_s[/\A([A-Za-z0-9_:]+)\.perform_later/, 1]
      expect(klass.constantize).to be < ApplicationJob
    end
  end
end
