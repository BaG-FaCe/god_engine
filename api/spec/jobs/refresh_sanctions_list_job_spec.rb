require 'rails_helper'

RSpec.describe SupplyChainRisk::RefreshSanctionsListJob, type: :job do
  include ActiveJob::TestHelper

  let(:eu_csv) do
    <<~CSV
      NameAlias,Regulation,ListedOn,SubjectType
      "Sibur Holding Ltd","2023/123",2023-01-01,entity
    CSV
  end
  let(:ofac_csv) { "123,ROSNEFT OIL COMPANY,-0- ,SDGT,,,,,,,,,,,\n" }

  before do
    stub_request(:get, %r{webgate\.ec\.europa\.eu}).to_return(status: 200, body: eu_csv)
    stub_request(:get, %r{sanctionslistservice\.ofac\.treas\.gov}).to_return(status: 200, body: ofac_csv)
  end

  it 'is scheduled on the risk polling queue' do
    expect(described_class.queue_name).to eq('risk_polling')
  end

  it 'imports both lists into the database (not just the cache)' do
    expect { described_class.perform_now }.to change(SanctionsEntry, :count).by(2)

    expect(SanctionsEntry.by_source('eu_consolidated').count).to eq(1)
    expect(SanctionsEntry.by_source('ofac_sdn').count).to eq(1)
  end

  it 'is idempotent across repeated runs (upsert)' do
    described_class.perform_now
    expect { described_class.perform_now }.not_to change(SanctionsEntry, :count)
  end

  it 'screens suppliers and marks clear ones' do
    supplier = create(:supplier, name: 'Unverdaechtige GmbH')
    described_class.perform_now

    expect(supplier.reload.sanctions_status).to eq('clear')
  end

  it 'flags a supplier whose name matches a listed entity' do
    supplier = create(:supplier, name: 'Sibur Holding')
    described_class.perform_now

    expect(supplier.reload.sanctions_status).to eq('flagged')
  end
end
