module Calculator
  module Application
    # Loads a project aggregate into the pure `CostBasis` value object consumed
    # by `PricingCalculator` / `PriceOptimizer`. This is the ONLY place that
    # translates Active Record into domain value objects (ports & adapters).
    class BuildCostBasis
      class << self
        def call(project:, units_per_month: nil, batch_size: nil)
          project = Project.includes(
            :materials, :monthly_costs, :labor_costs, :fixed_costs, :overhead_rules
          ).find(project.id) unless project.association(:materials).loaded?

          risk = SupplyChainRisk::Application::AggregateProductRisk.call(project: project)

          Domain::CostBasis.new(
            inputs: Domain::CostBasis::Inputs.new(
              units_per_month: units_per_month || project.units_per_month,
              batch_size: batch_size || project.batch_size,
              tax_rate: project.tax_rate_fraction,
              risk_surcharge_pct: project.risk_surcharge_pct,
              auto_risk_surcharge: project.auto_risk_surcharge?,
              tax_exempt: project.tax_profile == 'kleinunternehmer',
              tax_profile: project.tax_profile,
              country: project.country
            ),
            materials: project.materials.map { |material| material_line(project, material) },
            monthly_costs: project.monthly_costs.map do |row|
              Domain::CostBasis::MonthlyLine.new(
                id: row.id, name: row.name, category: row.category, amount_cents: row.amount_cents
              )
            end,
            labor_costs: project.labor_costs.map do |row|
              Domain::CostBasis::LaborLine.new(
                id: row.id, employee: row.employee, role: row.role,
                hours: row.hours, hourly_rate_cents: row.hourly_rate_cents
              )
            end,
            fixed_costs: project.fixed_costs.map do |row|
              Domain::CostBasis::FixedLine.new(
                id: row.id, name: row.name, category: row.category,
                amount_cents: row.amount_cents, allocation_basis: row.allocation_basis
              )
            end,
            overhead_rules: project.overhead_rules.enabled.ordered.map do |rule|
              Domain::CostBasis::OverheadLine.new(
                id: rule.id, key: rule.key, name: rule.name,
                percentage: rule.percentage, base: rule.base,
                auto_from_risk: rule.auto_from_risk?, position: rule.position
              )
            end,
            risk: Domain::CostBasis::RiskInput.new(
              aggregate_score: risk[:aggregateScore],
              level: risk[:level],
              material_count: risk[:materialCount],
              critical_material_count: risk[:criticalMaterialCount],
              single_source_count: risk[:singleSourceCount],
              has_data: risk[:hasData],
              reason: risk[:reason],
              data_sources: risk[:dataSources]
            ),
            currency: project.currency
          )
        end

        private

        def material_line(project, material)
          profile = material.material_risk_profile
          Domain::CostBasis::MaterialLine.new(
            id: material.id, name: material.name, article_number: material.article_number,
            quantity: material.quantity, unit_net_price_cents: material.net_unit_price_cents,
            unit: material.unit, supplier_name: material.supplier&.name,
            lead_time_days: material.lead_time_days, risk_level: material.risk_level,
            risk_score: material.risk_score,
            is_single_source: profile&.is_single_source? || material.supplier&.is_single_source? || false
          )
        end
      end
    end
  end
end
