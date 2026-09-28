require 'rails_helper'

RSpec.describe SupplyChainRisk::Application::RefreshMaterialRisk do
  # Regression test for the per-project configuration fix: an endpoint stored in
  # `risk_provider_configs.config` must actually reach the adapter. Before the
  # fix only the encrypted API key was forwarded and `baseUrl`/`assessmentPath`
  # overrides were silently ignored, so `eu_taric` could never answer.
  it 'forwards the per-project config (baseUrl/assessmentPath) to the adapter' do
    project = create(:project)
    material = create(:material, :with_risk_profile, project: project)

    create(:risk_provider_config, project: project, provider_key: 'eu_taric',
                                  config: { 'baseUrl' => 'https://taric.example.com',
                                            'assessmentPath' => '/api/measures' })

    stub_request(:get, %r{taric\.example\.com}).to_return(
      status: 200,
      body: JSON.generate(JSON.parse(File.read(Rails.root.join('spec/fixtures/risk/eu_taric.json')))),
      headers: { 'Content-Type' => 'application/json' }
    )

    expect do
      described_class.call(material: material, provider_keys: ['eu_taric'])
    end.to change { RiskAssessment.where(provider_key: 'eu_taric').count }.by(1)
  end

  it 'still skips eu_taric when no endpoint is configured' do
    project = create(:project)
    material = create(:material, :with_risk_profile, project: project)

    expect do
      described_class.call(material: material, provider_keys: ['eu_taric'])
    end.not_to change { RiskAssessment.where(provider_key: 'eu_taric').count }
  end
end
