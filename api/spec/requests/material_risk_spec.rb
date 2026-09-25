require 'rails_helper'

RSpec.describe 'MaterialRisk API', type: :request do
  let(:project) { create(:project) }
  let(:material) { create(:material, :with_risk_profile, project: project) }

  describe 'GET /api/v1/materials/:id/risk_assessment' do
    it 'returns the aggregated material view' do
      create(:risk_assessment, material: material)
      material.update_columns(risk_score: 42, risk_level: 'medium')
      get "/api/v1/materials/#{material.id}/risk_assessment"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['materialId']).to eq(material.id)
      expect(body['riskScore']).to eq(42)
      expect(body['assessments']).to be_present
    end
  end

  describe 'POST /api/v1/materials/:id/risk_assessment/manual' do
    it 'records a manual Ampel and persists a manual assessment' do
      post "/api/v1/materials/#{material.id}/risk_assessment/manual",
           params: { level: 'red', note: 'kritisch', score: 85 }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(material.reload.risk_level).to eq('high')
      assessment = material.risk_assessments.find_by(provider_key: 'manual')
      expect(assessment).to be_present
      expect(assessment.origin).to eq('manual')
    end
  end

  describe 'POST /api/v1/materials/:id/risk_assessment/refresh' do
    it 'queues the refresh job' do
      expect do
        post "/api/v1/materials/#{material.id}/risk_assessment/refresh", headers: auth_headers
      end.to have_enqueued_job(SupplyChainRisk::RefreshMaterialRiskJob).with(material.id)

      expect(response).to have_http_status(:accepted)
    end
  end
end
