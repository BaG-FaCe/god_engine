module SupplyChainRisk
  module Application
    # Runs the active providers for ONE material and persists the assessments.
    # Called synchronously from the refresh endpoint (small fan-out) and from
    # the recurring jobs for bulk refreshes.
    class RefreshMaterialRisk
      Result = Data.define(:material_id, :assessments, :events, :aggregate) do
        def to_h
          {
            materialId: material_id,
            assessmentsWritten: assessments.size,
            eventsWritten: events.size,
            aggregate: aggregate
          }
        end
      end

      class << self
        def call(material:, provider_keys: nil, user: nil)
          project = material.project
          subject = Domain::Subject.from_material(material)
          descriptors = Infrastructure::ProviderRegistry.active_for(project)
          descriptors = descriptors.select { |descriptor| provider_keys.include?(descriptor.key) } if provider_keys

          assessments = descriptors.filter_map do |descriptor|
            assess_with(descriptor, subject, material, project)
          end

          update_denormalised(material, assessments)
          aggregate = AggregateProductRisk.call(project: project)

          Result.new(
            material_id: material.id,
            assessments: assessments,
            events: [],
            aggregate: aggregate
          )
        end

        private

        def assess_with(descriptor, subject, material, project)
          context = build_context(descriptor, project)
          provider = descriptor.provider_class.instantiate(context: context)
          return nil unless provider.available?

          draft = provider.assess(subject)
          return nil if draft.nil?

          RiskAssessment.create!(draft.to_assessment_attributes(material_id: material.id))
        rescue StandardError => e
          Rails.logger.warn("[supply-chain-risk] #{descriptor.key} failed for #{material.id}: #{e.message}")
          nil
        end

        def build_context(descriptor, project)
          config = RiskProviderConfig.for_project(project).find_by(provider_key: descriptor.key)
          Domain::ProviderContext.new(
            descriptor: descriptor,
            config: { api_key: config&.api_key },
            project_id: project&.id
          )
        end

        def update_denormalised(material, assessments)
          fresh = assessments.reject(&:stale?).max_by(&:fetched_at) || assessments.max_by(&:fetched_at)
          # Manual assessments never expire: fall back to the internal heuristic.
          if fresh.nil?
            manual = material.risk_assessments.newest_first.first
            fresh = manual
          end
          return if fresh.nil?

          material.update_columns(
            risk_score: fresh.risk_score, risk_level: fresh.risk_level,
            last_risk_checked_at: fresh.fetched_at, updated_at: Time.current
          )
        end
      end
    end
  end
end
