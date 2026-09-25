require 'rails_helper'

RSpec.describe SupplyChainRisk::Domain::EventDraft do
  let(:project) { create(:project) }

  describe '.build' do
    it 'normalises the source event id and country code' do
      draft = described_class.build(
        source: 'gdacs', source_event_id: 123, event_type: 'disaster',
        severity: 'high', title: 'X', country_code: 'cn', occurred_at: Time.current
      )

      expect(draft.source_event_id).to eq('123')
      expect(draft.country_code).to eq('CN')
    end
  end

  describe '#valid?' do
    it 'rejects unknown event types and severities' do
      expect(described_class.build(source: 's', event_type: 'nope', severity: 'high',
                                   title: 'X', occurred_at: Time.current).valid?).to be(false)
      expect(described_class.build(source: 's', event_type: 'disaster', severity: 'nope',
                                   title: 'X', occurred_at: Time.current).valid?).to be(false)
      expect(described_class.build(source: 's', event_type: 'disaster', severity: 'high',
                                   title: 'X', occurred_at: Time.current).valid?).to be(true)
    end
  end

  describe '#persist! (idempotent ingestion)' do
    let(:draft) do
      described_class.build(
        source: 'gdacs', source_event_id: 'evt-1', event_type: 'disaster',
        severity: 'high', title: 'Typhoon', description: 'first', country_code: 'CN',
        occurred_at: 2.hours.ago, project_id: project.id
      )
    end

    it 'creates the event and a notification on the first persist' do
      expect { draft.persist! }.to change(RiskEvent, :count).by(1)
                               .and change(RiskNotification, :count).by(1)

      event = RiskEvent.find_by(source: 'gdacs', source_event_id: 'evt-1')
      expect(event).to be_persisted
      expect(event.acknowledged_at).to be_nil
    end

    it 'updates nothing and notifies nobody when the same event is polled again' do
      draft.persist!
      redraft = described_class.build(
        source: 'gdacs', source_event_id: 'evt-1', event_type: 'disaster',
        severity: 'critical', title: 'Typhoon', description: 'updated',
        country_code: 'CN', occurred_at: 2.hours.ago, project_id: project.id
      )

      expect { redraft.persist! }.not_to change(RiskEvent, :count)
      expect { redraft.persist! }.not_to change(RiskNotification, :count)

      event = RiskEvent.find_by(source: 'gdacs', source_event_id: 'evt-1')
      expect(event.severity).to eq('critical') # refreshed with new information
      expect(event.description).to eq('updated')
    end

    it 'returns nil without writing for an invalid draft' do
      invalid = described_class.build(source: 's', source_event_id: 'x', event_type: 'nope',
                                      severity: 'high', title: 'X', occurred_at: Time.current)
      expect { invalid.persist! }.not_to change(RiskEvent, :count)
      expect(invalid.persist!).to be_nil
    end
  end
end
