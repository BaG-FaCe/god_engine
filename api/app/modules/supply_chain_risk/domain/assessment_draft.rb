module SupplyChainRisk
  module Domain
    # What a provider returns: a normalised, *unpersisted* assessment.
    #
    # Every provider - open data, internal heuristic or commercial platform - has
    # to produce this shape. That is the whole point of the abstraction: the
    # rest of the application never learns which vendor answered.
    AssessmentDraft = Data.define(
      :provider_key, :provider_name, :provider_tier, :risk_score, :dimensions,
      :lead_time_variance_days, :reason, :data_sources, :raw_payload,
      :confidence, :expires_in
    ) do
      MAX_SCORE = 100

      def self.build(provider_key:, provider_name:, provider_tier:, risk_score:,
                     dimensions: {}, lead_time_variance_days: nil, reason: nil,
                     data_sources: [], raw_payload: nil, confidence: nil,
                     expires_in: nil)
        new(
          provider_key: provider_key,
          provider_name: provider_name,
          provider_tier: provider_tier,
          risk_score: clamp(risk_score),
          dimensions: normalise_dimensions(dimensions),
          lead_time_variance_days: lead_time_variance_days,
          reason: reason,
          data_sources: Array(data_sources),
          raw_payload: raw_payload,
          confidence: confidence,
          expires_in: expires_in
        )
      end

      def self.clamp(score)
        value = score.nil? ? 0 : score.to_f.round
        [[value, 0].max, MAX_SCORE].min
      end

      # Only the known dimension keys survive, each clamped to 0-100.
      def self.normalise_dimensions(dimensions)
        source = (dimensions || {}).transform_keys(&:to_s)
        RiskAssessment::DIMENSION_KEYS.index_with do |key|
          raw = source[key]
          raw.nil? ? nil : [[raw.to_f.round, 0].max, MAX_SCORE].min
        end
      end

      def risk_level
        RiskAssessment.level_for(risk_score)
      end

      def dimensions_list
        dimensions.compact.keys
      end

      # Attributes for `RiskAssessment.create!`.
      def to_assessment_attributes(material_id:, fetched_at: Time.current)
        {
          material_id: material_id,
          provider_key: provider_key,
          provider_name: provider_name,
          provider_tier: provider_tier,
          risk_score: risk_score,
          risk_level: risk_level,
          dimensions: dimensions,
          lead_time_variance_days: lead_time_variance_days,
          reason: reason,
          origin: 'automatic',
          fetched_at: fetched_at,
          expires_at: expires_in && fetched_at + expires_in,
          data_sources: data_sources,
          raw_payload: raw_payload,
          confidence: confidence
        }
      end

      def to_h
        {
          providerKey: provider_key,
          providerName: provider_name,
          providerTier: provider_tier,
          riskScore: risk_score,
          riskLevel: risk_level,
          dimensions: dimensions,
          leadTimeVarianceDays: lead_time_variance_days,
          reason: reason,
          dataSources: data_sources,
          confidence: confidence
        }
      end
    end
  end
end