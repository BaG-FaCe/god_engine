# One data source name of a `RiskAssessment` (formerly the
# `risk_assessments.data_sources` JSON array of strings).
class RiskAssessmentDataSource < ApplicationRecord
  belongs_to :risk_assessment, inverse_of: :risk_assessment_data_sources

  validates :name, presence: true, length: { maximum: 255 }

  scope :ordered, -> { order(:position, :name) }
end
