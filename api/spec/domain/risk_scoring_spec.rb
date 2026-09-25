require 'rails_helper'

RSpec.describe 'Risikoscoring (Domain)' do
  describe SupplyChainRisk::Domain::AssessmentDraft do
    it 'clamps scores into 0..100 and derives the traffic light' do
      expect(described_class.build(provider_key: 'x', provider_name: 'X', provider_tier: 'free',
                                   risk_score: -5).risk_score).to eq(0)
      expect(described_class.build(provider_key: 'x', provider_name: 'X', provider_tier: 'free',
                                   risk_score: 999).risk_score).to eq(100)
      expect(described_class.build(provider_key: 'x', provider_name: 'X', provider_tier: 'free',
                                   risk_score: 50).risk_level).to eq('medium')
    end

    it 'normalises dimensions to the known keys only and clamps each value' do
      draft = described_class.build(
        provider_key: 'x', provider_name: 'X', provider_tier: 'free', risk_score: 20,
        dimensions: { 'logistics' => 140, 'bogus' => 50 }
      )

      expect(draft.dimensions.keys).to contain_exactly(*RiskAssessment::DIMENSION_KEYS)
      expect(draft.dimensions['logistics']).to eq(100)
      expect(draft.dimensions['bogus']).to be_nil
    end

    it 'produces persistable assessment attributes with a fetched_at and expiry' do
      draft = described_class.build(provider_key: 'gdacs', provider_name: 'GDACS',
                                    provider_tier: 'free', risk_score: 55,
                                    expires_in: 30.minutes)
      attributes = draft.to_assessment_attributes(material_id: 'm1', fetched_at: Time.current)

      expect(attributes[:expires_at]).to be_within(2.seconds).of(30.minutes.from_now)
      expect(attributes[:origin]).to eq('automatic')
      expect(attributes[:risk_level]).to eq('medium')
    end
  end

  describe RiskAssessment, '.level_for' do
    it 'maps the 0..100 scale onto the three traffic lights' do
      expect(described_class.level_for(0)).to eq('low')
      expect(described_class.level_for(33)).to eq('low')
      expect(described_class.level_for(34)).to eq('medium')
      expect(described_class.level_for(66)).to eq('medium')
      expect(described_class.level_for(67)).to eq('high')
      expect(described_class.level_for(100)).to eq('high')
      expect(described_class.level_for(nil)).to eq('low')
    end
  end

  describe RiskAssessment, '#dimension_scores' do
    it 'normalises free-form dimension hashes for the material card' do
      assessment = build(:risk_assessment, dimensions: { 'logistics' => '42', 'weather' => -1 })
      expect(assessment.dimension_scores['logistics']).to eq(42)
      expect(assessment.dimension_scores['weather']).to eq(0)
      expect(assessment.dimension_scores['financial']).to be_nil
    end
  end
end
