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

  # Normalises the free-form dimension hash to all known keys.
  def dimension_scores
    stored = (dimensions || {}).stringify_keys
    DIMENSION_KEYS.index_with do |key|
      raw = stored[key]
      raw.nil? ? nil : [[raw.to_f.round, 0].max, MAX_SCORE].min
    end
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