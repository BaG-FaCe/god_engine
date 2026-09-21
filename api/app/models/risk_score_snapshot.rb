# Daily roll-up of a material's risk score.
#
# Written once per day by `SupplyChainRisk::CaptureRiskSnapshotsJob`. Keeping the
# history in a dedicated table (instead of re-deriving it from the assessments)
# makes the timeline chart a cheap indexed range scan.
class RiskScoreSnapshot < ApplicationRecord
  belongs_to :material, inverse_of: :risk_score_snapshots

  validates :captured_on, presence: true, uniqueness: { scope: :material_id }
  validates :risk_score, numericality: { only_integer: true, in: 0..100 }
  validates :risk_level, inclusion: { in: %w[low medium high] }
  validates :event_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :chronological, -> { order(:captured_on) }
  scope :since, ->(date) { where(captured_on: date..) }
  scope :for_materials, ->(ids) { where(material_id: ids) }

  # Average score per day across a set of materials - the timeline series.
  def self.daily_average(material_ids, since: 30.days.ago.to_date)
    where(material_id: material_ids)
      .since(since)
      .group(:captured_on)
      .order(:captured_on)
      .pluck(:captured_on, Arel.sql('AVG(risk_score)'), Arel.sql('SUM(event_count)'))
      .map do |(date, average, events)|
        {
          date: date.to_s,
          averageRiskScore: average.to_f.round(2),
          eventCount: events.to_i
        }
      end
  end
end