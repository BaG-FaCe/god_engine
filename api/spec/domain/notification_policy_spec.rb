require 'rails_helper'

RSpec.describe SupplyChainRisk::Domain::NotificationPolicy do
  describe '.notify_for_event?' do
    let(:event) { build(:risk_event) }

    it 'requires a persisted event' do
      expect(described_class.notify_for_event?(event)).to be(false)
      event.save!
      expect(described_class.notify_for_event?(event)).to be(true)
    end

    it 'suppresses a second notification for the same event (idempotency)' do
      event.save!
      create(:risk_notification, kind: 'risk_event', risk_event: event)

      expect(described_class.notify_for_event?(event)).to be(false)
    end

    it 'honours the configurable severity floor' do
      allow(ENV).to receive(:fetch)
        .with('RISK_NOTIFICATION_MIN_SEVERITY', '').and_return('high')

      expect(described_class.notify_for_event?(build(:risk_event, severity: 'low').tap(&:save!))).to be(false)
      expect(described_class.notify_for_event?(build(:risk_event, severity: 'high').tap(&:save!))).to be(true)
    end
  end

  describe '.notify_for_material?' do
    it 'notifies when the aggregated level turns red' do
      material = build(:material, risk_level: 'high', risk_score: 80)
      expect(described_class.notify_for_material?(material, previous_level: 'medium')).to be(true)
    end

    it 'notifies when the score changes while staying red' do
      material = build(:material, risk_level: 'high', risk_score: 90)
      expect(described_class.notify_for_material?(material, previous_level: 'high',
                                                          previous_score: 80)).to be(true)
    end

    it 'stays silent when red is unchanged' do
      material = build(:material, risk_level: 'high', risk_score: 80)
      expect(described_class.notify_for_material?(material, previous_level: 'high',
                                                          previous_score: 80)).to be(false)
    end

    it 'stays silent below red' do
      material = build(:material, risk_level: 'medium', risk_score: 40)
      expect(described_class.notify_for_material?(material, previous_level: 'low')).to be(false)
    end
  end
end
