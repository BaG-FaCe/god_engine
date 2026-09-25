module SupplyChainRisk
  # Removes expired assessments + writes the daily timeline snapshot.
  class PurgeExpiredAssessmentsJob < ApplicationJob
    queue_as :maintenance

    def perform
      purged = RiskAssessment.expired.delete_all
      Material.find_each do |material|
        next if material.risk_score.nil?

        RiskScoreSnapshot.upsert(
          { id: SecureRandom.uuid, material_id: material.id, captured_on: Date.current,
            risk_score: material.risk_score, risk_level: material.risk_level || 'low',
            event_count: material.risk_events.since(24.hours.ago).count,
            created_at: Time.current, updated_at: Time.current },
          unique_by: %i[material_id captured_on],
          update_only: %i[risk_score risk_level event_count updated_at]
        )
      end
      purged
    end
  end
end
