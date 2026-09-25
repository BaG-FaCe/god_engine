require 'rails_helper'

RSpec.describe SupplyChainRisk::SyncFreightIndexJob, type: :job do
  include ActiveJob::TestHelper

  it 'is scheduled on the risk polling queue' do
    expect(described_class.queue_name).to eq('risk_polling')
  end

  it 'skips without a configured key and makes no upstream call' do
    expect(described_class.perform_now).to eq(0)
    expect(WebMock).not_to have_requested(:any, %r{freightos\.com})
  end

  it 'writes the freight index into Solid Cache when a key is configured' do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('FREIGHTOS_API_KEY').and_return('fixture-key')
    stub_request(:get, %r{api\.freightos\.com}).to_return(
      status: 200,
      body: JSON.generate(JSON.parse(File.read(Rails.root.join('spec/fixtures/risk/freightos_fbx.json')))),
      headers: { 'Content-Type' => 'application/json' }
    )

    expect(described_class.perform_now).to eq(1)
    expect(Rails.cache.read('scr:freight_index')).to be_present
  end

  it 'survives an unreachable provider without failing the job' do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('FREIGHTOS_API_KEY').and_return('fixture-key')
    stub_request(:get, %r{api\.freightos\.com}).to_timeout

    expect { described_class.perform_now }.not_to raise_error
  end
end
