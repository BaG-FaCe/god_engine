module SupplyChainRisk
  module Application
    # Aggregates per-material risk into the product-level view consumed by the
    # calculator (risk surcharge), the dashboard and the pricing endpoint.
    #
    # Reads only `materials.risk_score/risk_level` (denormalised) — never the
    # risk tables — so callers stay decoupled from this module's persistence.
    class AggregateProductRisk
      class << self
        def call(project:)
          materials = project.materials.to_a
          scored = materials.select { |material| material.risk_score.present? }

          if scored.empty?
            return {
              aggregateScore: nil, level: nil, materialCount: materials.size,
              criticalMaterialCount: 0, singleSourceCount: single_source_count(materials),
              hasData: false, reason: 'Keine Risikodaten vorhanden',
              dataSources: []
            }
          end

          scores = scored.map(&:risk_score)
          average = (scores.sum.to_f / scores.size).round
          {
            aggregateScore: average,
            level: RiskAssessment.level_for(average),
            materialCount: materials.size,
            criticalMaterialCount: scored.count { |material| material.risk_level == 'high' },
            singleSourceCount: single_source_count(materials),
            hasData: true,
            reason: "Durchschnitt über #{scored.size} von #{materials.size} bewerteten Materialien",
            dataSources: scored.filter_map { |material| material.latest_risk_assessment&.provider_name }.uniq
          }
        end

        # Per-material aggregated view for the material card (`risk:` block).
        def material_view(material)
          assessments = material.risk_assessments.newest_first.limit(10).to_a
          profile = material.material_risk_profile
          last_event = material.risk_events.recent.first

          {
            materialId: material.id,
            riskScore: material.risk_score,
            riskLevel: material.risk_level,
            ampel: ampel_for(material.risk_level),
            dimensions: assessments.first&.dimension_scores ||
              RiskAssessment::DIMENSION_KEYS.index_with { nil },
            lastCheckedAt: material.last_risk_checked_at&.iso8601,
            hasAutomaticData: assessments.any? { |assessment| assessment.origin != 'manual' },
            hasManualData: profile&.manually_assessed? || assessments.any? { |a| a.origin == 'manual' },
            dataSources: assessments.flat_map { |a| Array(a.data_sources) }.uniq.first(5),
            sanctionsStatus: material.supplier&.sanctions_status || 'unknown',
            originCountry: profile&.origin_country,
            hsCode: profile&.hs_code,
            shippingRoute: profile&.shipping_route,
            alternativeSupplierCount: material.alternative_suppliers.size,
            lastEvent: last_event && serialize_event(last_event),
            assessments: assessments.map { |a| serialize_assessment(a) },
            manualAssessment: profile&.manually_assessed? ? {
              level: profile.manual_risk_level,
              note: profile.manual_risk_note,
              assessedAt: profile.manually_assessed_at&.iso8601
            } : nil
          }
        end

        private

        def single_source_count(materials)
          materials.count do |material|
            material.material_risk_profile&.is_single_source? ||
              material.supplier&.is_single_source?
          end
        end

        def ampel_for(level)
          { 'low' => 'green', 'medium' => 'yellow', 'high' => 'red' }.fetch(level.to_s, 'unknown')
        end

        def serialize_assessment(assessment)
          {
            id: assessment.id, materialId: assessment.material_id,
            providerKey: assessment.provider_key, providerName: assessment.provider_name,
            providerTier: assessment.provider_tier, riskScore: assessment.risk_score,
            riskLevel: assessment.risk_level, dimensions: assessment.dimension_scores,
            leadTimeVarianceDays: assessment.lead_time_variance_days,
            reason: assessment.reason, origin: assessment.origin,
            fetchedAt: assessment.fetched_at&.iso8601,
            expiresAt: assessment.expires_at&.iso8601,
            stale: assessment.stale?,
            dataSources: Array(assessment.data_sources), rawPayload: nil
          }
        end

        def serialize_event(event)
          {
            id: event.id, materialId: event.material_id, projectId: event.project_id,
            countryCode: event.country_code, eventType: event.event_type,
            severity: event.severity, title: event.title, description: event.description,
            source: event.source, sourceEventId: event.source_event_id,
            occurredAt: event.occurred_at&.iso8601,
            acknowledgedAt: event.acknowledged_at&.iso8601, metadata: event.metadata
          }
        end
      end
    end
  end
end
