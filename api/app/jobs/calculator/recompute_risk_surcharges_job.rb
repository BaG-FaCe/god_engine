module Calculator
  # Recomputes `auto_from_risk` overhead rules from the aggregate score (daily).
  class RecomputeRiskSurchargesJob < ApplicationJob
    queue_as :maintenance

    def perform(project_id = nil)
      scope = project_id ? Project.where(id: project_id) : Project.all
      updated = 0
      scope.find_each do |project|
        risk = SupplyChainRisk::Application::AggregateProductRisk.call(project: project)
        policy = Domain::RiskSurchargePolicy.call(
          aggregate_score: risk[:aggregateScore],
          material_count: risk[:materialCount],
          critical_material_count: risk[:criticalMaterialCount],
          single_source_count: risk[:singleSourceCount]
        )
        project.overhead_rules.auto_from_risk.find_each do |rule|
          floor = BigDecimal(rule.percentage.to_s)
          rule.update!(percentage: [policy.applied_pct, floor].max)
          updated += 1
        end
      end
      updated
    end
  end
end
