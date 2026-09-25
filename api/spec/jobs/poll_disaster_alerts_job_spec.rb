require 'rails_helper'

RSpec.describe SupplyChainRisk::PollDisasterAlertsJob, type: :job do
  include ActiveJob::TestHelper

  let(:gdacs_body) do
    JSON.generate(JSON.parse(File.read(Rails.root.join('spec/fixtures/risk/gdacs.json'))))
  end

  before do
    stub_request(:get, %r{gdacs\.org}).to_return(status: 200, body: gdacs_body,
                                                  headers: { 'Content-Type' => 'application/json' })
    stub_request(:get, %r{earthquake\.usgs\.gov}).to_return(status: 200, body: '{"features":[]}')
    stub_request(:post, %r{api\.reliefweb\.int}).to_return(status: 200, body: '{"data":[]}')
  end

  it 'is scheduled on the risk polling queue' do
    expect(described_class.queue_name).to eq('risk_polling')
  end

  it 'persists new events from the feed and notifies once per event' do
    expect { described_class.perform_now }.to change(RiskEvent, :count).by(2)
                                         .and change(RiskNotification, :count).by(2)
  end

  it 'is idempotent across repeated polls (upsert on source+source_event_id)' do
    described_class.perform_now

    expect { described_class.perform_now }.not_to change(RiskEvent, :count)
    expect { described_class.perform_now }.not_to change(RiskNotification, :count)
  end

  it 'skips providers disabled by a project configuration' do
    create(:risk_provider_config, provider_key: 'gdacs', enabled: false, poll_interval_minutes: 30)

    expect { described_class.perform_now }.not_to change(RiskEvent, :count)
  end

  it 'keeps running when one provider fails' do
    stub_request(:get, %r{gdacs\.org}).to_timeout

    expect { described_class.perform_now }.not_to raise_error
  end
end
