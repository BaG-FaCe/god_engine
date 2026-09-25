require 'rails_helper'

RSpec.describe SupplyChainRisk::Application::NotifyRiskAlert do
  let(:project) { create(:project) }

  describe '.for_event!' do
    it 'creates a notification with the deep-link payload' do
      event = create(:risk_event, project: project, severity: 'critical', material: nil)

      notification = described_class.for_event!(event)

      expect(notification).to be_a(RiskNotification)
      expect(notification.kind).to eq('risk_event')
      expect(notification.risk_event_id).to eq(event.id)
      expect(notification.payload['riskEventId']).to eq(event.id)
      expect(notification.payload['countryCode']).to eq('CN')
    end

    it 'is idempotent via the policy' do
      event = create(:risk_event, project: project)
      described_class.for_event!(event)

      expect { described_class.for_event!(event) }.not_to change(RiskNotification, :count)
    end
  end

  describe '.for_material!' do
    let(:material) { create(:material, project: project, risk_score: 88, risk_level: 'high') }

    it 'notifies on the red flip' do
      notification = described_class.for_material!(material, previous_level: 'medium')
      expect(notification.kind).to eq('critical_material')
      expect(notification.payload['materialId']).to eq(material.id)
    end

    it 'stays silent when red is unchanged' do
      expect(described_class.for_material!(material, previous_level: 'high',
                                                     previous_score: 88)).to be_nil
    end
  end
end
