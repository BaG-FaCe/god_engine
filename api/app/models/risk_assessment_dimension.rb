# One dimension score of a `RiskAssessment` (formerly the
# `risk_assessments.dimensions` JSON hash: `{ key => score }`).
class RiskAssessmentDimension < ApplicationRecord
  DIMENSION_KEYS = RiskAssessment::DIMENSION_KEYS

  belongs_to :risk_assessment, inverse_of: :risk_assessment_dimensions

  validates :dimension_key, presence: true, inclusion: { in: DIMENSION_KEYS }
  validates :score, numericality: { only_integer: true, in: 0..RiskAssessment::MAX_SCORE }

  scope :ordered, -> { order(:position, :dimension_key) }
end
