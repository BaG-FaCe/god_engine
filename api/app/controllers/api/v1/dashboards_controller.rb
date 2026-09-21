module Api
  module V1
    # Tab 5 — dashboard composition (KPIs + charts + risk roll-up).
    class DashboardsController < ApplicationController
      before_action :set_project

      def show
        basis = Calculator::Application::BuildCostBasis.call(project: @project)
        pricing = Calculator::Domain::PricingCalculator.new(basis).call
        totals = pricing.totals
        risk = SupplyChainRisk::Application::AggregateProductRisk.call(project: @project)
        forecasts = @project.sales_forecasts.ordered.to_a

        price = resolve_price(totals)
        units = @project.effective_units_per_month
        variable_per_unit = variable_cost_per_unit(totals)
        fixed_per_month = fixed_cost_per_month(basis, totals)
        contribution = price[:netCents] - variable_per_unit
        profit_per_unit = price[:netCents] - totals[:perUnitNetCents].to_i

        render json: {
          projectId: @project.id,
          kpis: {
            materialCostCents: totals[:materialCostCents],
            monthlyCostCents: totals[:monthlyCostCents],
            fixedCostCents: totals[:fixedCostCents],
            laborCostCents: totals[:laborCostCents],
            overheadCents: totals[:overheadCents],
            riskSurchargeCents: totals[:riskSurchargeCents],
            totalCostNetCents: totals[:totalCostNetCents],
            totalCostGrossCents: totals[:totalCostGrossCents],
            perUnitNetCents: totals[:perUnitNetCents],
            perUnitGrossCents: totals[:perUnitGrossCents],
            sellingPriceNetCents: price[:netCents],
            sellingPriceGrossCents: price[:grossCents],
            profitPerUnitNetCents: profit_per_unit,
            profitMarginPct: price[:netCents].zero? ? 0 : (profit_per_unit.to_f / price[:netCents]).round(6),
            revenueMonthlyNetCents: price[:netCents] * units,
            monthlyProfitNetCents: profit_per_unit * units,
            breakEvenUnits: break_even_units(contribution, fixed_per_month),
            unitsPerMonth: units,
            criticalRiskCount: risk[:criticalMaterialCount],
            averageRiskScore: risk[:aggregateScore],
            materialCount: risk[:materialCount],
            riskLevel: risk[:level]
          },
          costDistribution: pricing.lines.map do |line|
            { key: line.key, label: line.label, totalCents: line.total_cents, share: line.share.to_f }
          end,
          profitTrend: profit_trend(forecasts, price[:netCents], variable_per_unit, fixed_per_month),
          forecastVsActual: forecasts.map do |row|
            { period: row.period, forecastUnits: row.forecast_units, actualUnits: row.actual_units }
          end,
          riskDistribution: risk_distribution,
          riskTimeline: RiskScoreSnapshot.daily_average(@project.materials.pluck(:id)),
          riskEvents: @project.risk_events.recent.limit(20).map { |event| event_json(event) },
          criticalRiskMaterials: @project.materials.critical_risk.limit(10).map do |material|
            { materialId: material.id, name: material.name, riskScore: material.risk_score,
              riskLevel: material.risk_level,
              originCountry: material.material_risk_profile&.origin_country,
              lastCheckedAt: material.last_risk_checked_at&.iso8601 }
          end
        }
      end

      private

      def set_project
        @project = Project.find(params[:project_id])
      end

      # Target price of the active scenario, otherwise the calculated price.
      def resolve_price(totals)
        tax_rate = BigDecimal(@project.tax_rate_fraction.to_s)
        scenario = @project.pricing_scenarios.active.first
        target = scenario&.target_price_cents

        if target.present? && target.positive?
          if scenario.target_price_includes_tax
            denominator = BigDecimal(1) + tax_rate
            net = denominator.zero? ? target : (BigDecimal(target.to_s) / denominator).round(0, half: :up).to_i
            { netCents: net, grossCents: target }
          else
            { netCents: target,
              grossCents: (BigDecimal(target.to_s) * (BigDecimal(1) + tax_rate)).round(0, half: :up).to_i }
          end
        else
          { netCents: totals[:perUnitNetCents].to_i, grossCents: totals[:perUnitGrossCents].to_i }
        end
      end

      def variable_cost_per_unit(totals)
        totals[:perUnitNetCents].to_i - totals[:perUnitMonthlyCents].to_i - totals[:perUnitFixedCents].to_i
      end

      def fixed_cost_per_month(basis, totals)
        per_month = basis.fixed_costs.select { |line| line.allocation_basis.to_s == 'per_month' }
                          .sum { |line| line.amount_cents.to_i }
        totals[:monthlyCostCents].to_i + per_month
      end

      def break_even_units(contribution, fixed_per_month)
        return nil if contribution <= 0 || fixed_per_month <= 0

        (BigDecimal(fixed_per_month.to_s) / BigDecimal(contribution.to_s)).ceil
      end

      def profit_trend(forecasts, price_net, variable_per_unit, fixed_per_month)
        forecasts.filter_map do |row|
          units = row.actual_units || row.forecast_units
          next if units.nil?

          revenue = price_net * units
          cost = (variable_per_unit * units) + fixed_per_month
          profit = revenue - cost
          {
            period: row.period, revenueNetCents: revenue, costNetCents: cost,
            profitNetCents: profit,
            marginPct: revenue.zero? ? 0 : (profit.to_f / revenue).round(6),
            forecastUnits: row.forecast_units, actualUnits: row.actual_units
          }
        end
      end

      def risk_distribution
        counts = @project.materials.group(:risk_level).count
        %w[low medium high].map { |level| { level: level, count: counts[level] || 0 } } +
          [{ level: 'unknown', count: @project.materials.where(risk_score: nil).count }]
      end

      def event_json(event)
        { id: event.id, materialId: event.material_id, projectId: event.project_id,
          eventType: event.event_type, severity: event.severity, title: event.title,
          description: event.description, source: event.source,
          occurredAt: event.occurred_at&.iso8601,
          acknowledgedAt: event.acknowledged_at&.iso8601 }
      end
    end
  end
end
