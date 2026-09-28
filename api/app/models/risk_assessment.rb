# `supply-chain-risk` context - one provider result for one material.
#
# Assessments are append-only: a refresh writes a new row instead of updating the
# previous one, so the risk history stays auditable and the timeline chart has
# real data to plot. `expires_at` drives staleness; the newest non-expired row
# wins when aggregating.
class RiskAssessment < ApplicationRecord
  PROVIDER_TIERS = %w[free paid internal].freeze
  LEVELS = %w[low medium high].freeze
  ORIGINS = %w[automatic manual hybrid].freeze

  DIMENSION_KEYS = %w[
    logistics geopolitical weather financial compliance operational
  ].freeze

  MAX_SCORE = 100

  belongs_to :material, inverse_of: :risk_assessments
  has_many :risk_assessment_dimensions, -> { order(:position, :dimension_key) },
            dependent: :destroy, inverse_of: :risk_assessment
  has_many :risk_assessment_data_sources, -> { order(:position, :name) },
            dependent: :destroy, inverse_of: :risk_assessment

  # Opaque external API response capture (special case, documented).
  serialize :raw_payload, coder: JSON

  validates :provider_key, :provider_name, presence: true
  validates :provider_tier, inclusion: { in: PROVIDER_TIERS }
  validates :risk_level, inclusion: { in: LEVELS }
  validates :origin, inclusion: { in: ORIGINS }
  validates :risk_score, numericality: { only_integer: true, in: 0..MAX_SCORE }
  validates :fetched_at, presence: true
  validates :confidence, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 },
                         allow_nil: true

  scope :fresh, -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }
  scope :expired, -> { where(expires_at: ...Time.current) }
  scope :newest_first, -> { order(fetched_at: :desc) }
  scope :for_provider, ->(key) { where(provider_key: key) }
  scope :automatic, -> { where(origin: %w[automatic hybrid]) }

  # Persists an `AssessmentDraft` together with its dimension scores and data
  # source names (formerly stored as JSON on the assessment row itself).
  def self.create_from_draft!(draft, material_id:, fetched_at: Time.current)
    transaction do
      assessment = create!(draft.to_assessment_attributes(material_id: material_id, fetched_at: fetched_at))
      draft.dimensions.each_with_index do |(key, score), index|
        next if score.nil?

        assessment.risk_assessment_dimensions.create!(dimension_key: key, score: score, position: index)
      end
      Array(draft.data_sources).each_with_index do |name, index|
        assessment.risk_assessment_data_sources.create!(name: name, position: index)
      end
      assessment
    end
  end

  # Normalises the dimension rows to all known keys.
  def dimension_scores
    stored = risk_assessment_dimensions.each_with_object({}) { |dim, hash| hash[dim.dimension_key] = dim.score }
    DIMENSION_KEYS.index_with do |key|
      raw = stored[key]
      raw.nil? ? nil : [[raw.to_f.round, 0].max, MAX_SCORE].min
    end
  end

  # Names of the data sources that contributed to this assessment.
  def data_sources
    risk_assessment_data_sources.map(&:name)
  end

  def stale?
    expires_at.present? && expires_at <= Time.current
  end

  def self.level_for(score)
    return 'low' if score.nil? || score < 34
    return 'medium' if score < 67

    'high'
  end
end
