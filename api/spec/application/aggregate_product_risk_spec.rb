require 'rails_helper'

RSpec.describe SupplyChainRisk::Application::AggregateProductRisk do
  let(:project) { create(:project) }

  it 'reports no data when no material has a score' do
    create(:material, project: project, risk_score: nil)
    result = described_class.call(project: project)

    expect(result[:hasData]).to be(false)
    expect(result[:aggregateScore]).to be_nil
    expect(result[:materialCount]).to eq(1)
  end

  it 'averages the per-material scores and derives the level' do
    create(:material, project: project, risk_score: 20, risk_level: 'low')
    create(:material, project: project, risk_score: 80, risk_level: 'high')

    result = described_class.call(project: project)

    expect(result[:hasData]).to be(true)
    expect(result[:aggregateScore]).to eq(50)
    expect(result[:level]).to eq('medium')
    expect(result[:criticalMaterialCount]).to eq(1)
  end

  it 'ignores materials without a score when aggregating' do
    create(:material, project: project, risk_score: 70, risk_level: 'high')
    create(:material, project: project, risk_score: nil)

    result = described_class.call(project: project)
    expect(result[:aggregateScore]).to eq(70)
    expect(result[:materialCount]).to eq(2)
  end

  describe '.material_view' do
    it 'exposes the traffic light and the latest assessment for the card' do
      material = create(:material, :with_risk_profile, project: project,
                                                       risk_score: 42, risk_level: 'medium')
      create(:risk_assessment, material: material)

      view = described_class.material_view(material)

      expect(view[:materialId]).to eq(material.id)
      expect(view[:riskScore]).to eq(42)
      expect(view[:ampel]).to eq('yellow')
      expect(view[:dataSources]).to include('Internes Heuristikmodell')
      expect(view[:assessments]).to be_present
    end
  end
end
