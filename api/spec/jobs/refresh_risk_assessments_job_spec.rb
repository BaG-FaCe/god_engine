require 'rails_helper'

RSpec.describe SupplyChainRisk::RefreshRiskAssessmentsJob, type: :job do
  include ActiveJob::TestHelper

  let(:project) { create(:project, risk_refresh_interval_hours: 24) }

  it 'is scheduled on the risk polling queue' do
    expect(described_class.queue_name).to eq('risk_polling')
  end

  it 'skips materials that were checked recently' do
    material = create(:material, :with_risk_profile, project: project,
                                                     last_risk_checked_at: 1.hour.ago)

    expect(described_class.perform_now(project.id)).to eq(0)
    expect(material.reload.risk_score).to be_nil
  end

  it 'refreshes stale materials' do
    create(:material, :with_risk_profile, project: project, last_risk_checked_at: 2.days.ago)

    expect { described_class.perform_now(project.id) }.to change(RiskAssessment, :count).by_at_least(1)
  end
end
