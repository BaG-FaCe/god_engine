require 'rails_helper'

RSpec.describe SupplyChainRisk::PurgeExpiredAssessmentsJob, type: :job do
  include ActiveJob::TestHelper

  it 'is scheduled on the maintenance queue' do
    expect(described_class.queue_name).to eq('maintenance')
  end

  it 'deletes only expired assessments' do
    material = create(:material)
    create(:risk_assessment, material: material)
    create(:risk_assessment, :expired, material: material)

    expect { described_class.perform_now }.to change(RiskAssessment, :count).by(-1)
    expect(RiskAssessment.where(material: material).count).to eq(1)
  end

  it 'writes a daily snapshot for scored materials' do
    create(:material, risk_score: 55, risk_level: 'medium')

    expect { described_class.perform_now }.to change(RiskScoreSnapshot, :count).by(1)
  end
end
