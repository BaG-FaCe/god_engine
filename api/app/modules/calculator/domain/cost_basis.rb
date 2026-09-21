module Calculator
  module Domain
    # The complete, pre-loaded input of a price calculation.
    #
    # `PricingCalculator` consumes only this object - never an Active Record
    # relation. `Calculator::Application::BuildCostBasis` maps the project
    # aggregate onto these value objects, which is what keeps the calculation
    # pure, synchronous and trivially unit-testable.
    class CostBasis
      # Volume and tax assumptions.
      Inputs = Data.define(
        :units_per_month, :batch_size, :tax_rate, :risk_surcharge_pct,
        :auto_risk_surcharge, :tax_exempt, :tax_profile, :country
      ) do
        def units_per_month!
          units_per_month.to_i.positive? ? units_per_month.to_i : 1
        end

        def batch_size!
          batch_size.to_i.positive? ? batch_size.to_i : 1
        end

        def tax_rate!
          Factories.decimal(tax_rate)
        end

        def effective_tax_rate
          tax_exempt ? BigDecimal(0) : tax_rate!
        end

        def to_h
          {
            unitsPerMonth: units_per_month!,
            batchSize: batch_size!,
            taxRate: tax_rate!.to_f.round(6),
            riskSurchargePct: risk_surcharge_pct && Float(risk_surcharge_pct),
            autoRiskSurcharge: auto_risk_surcharge ? true : false,
            taxExempt: tax_exempt ? true : false,
            taxProfile: tax_profile || 'standard',
            country: country || 'DE'
          }
        end
      end

      # One bill-of-materials position, per production batch.
      MaterialLine = Data.define(
        :id, :name, :article_number, :quantity, :unit_net_price_cents, :unit,
        :supplier_name, :lead_time_days, :risk_level, :risk_score, :is_single_source
      )

      MonthlyLine = Data.define(:id, :name, :category, :amount_cents)
      LaborLine = Data.define(:id, :employee, :role, :hours, :hourly_rate_cents)
      FixedLine = Data.define(:id, :name, :category, :amount_cents, :allocation_basis)

      # An overhead rule, resolved to plain values.
      OverheadLine = Data.define(:id, :key, :name, :percentage, :base, :auto_from_risk, :position)

      # Aggregated supply chain risk, as exposed by the risk module's public API.
      RiskInput = Data.define(
        :aggregate_score, :level, :material_count, :critical_material_count,
        :single_source_count, :has_data, :reason, :data_sources
      ) do
        def self.empty
          new(aggregate_score: nil, level: nil, material_count: 0,
              critical_material_count: 0, single_source_count: 0,
              has_data: false, reason: nil, data_sources: [])
        end

        def has_data?
          has_data ? true : false
        end
      end

      attr_reader :inputs, :materials, :monthly_costs, :labor_costs, :fixed_costs,
                  :overhead_rules, :risk, :currency

      def initialize(inputs:, materials: [], monthly_costs: [], labor_costs: [],
                     fixed_costs: [], overhead_rules: [], risk: nil, currency: 'EUR')
        @inputs = inputs
        @materials = materials.freeze
        @monthly_costs = monthly_costs.freeze
        @labor_costs = labor_costs.freeze
        @fixed_costs = fixed_costs.freeze
        @overhead_rules = overhead_rules.freeze
        @risk = risk || RiskInput.empty
        @currency = currency
        freeze
      end

      def units_per_month
        inputs.units_per_month!
      end

      def batch_size
        inputs.batch_size!
      end

      def tax_rate
        inputs.effective_tax_rate
      end

      def empty?
        materials.empty? && monthly_costs.empty? && labor_costs.empty? && fixed_costs.empty?
      end

      # Internal decimal coercion shared by the value objects.
      module Factories
        module_function

        def decimal(value)
          return BigDecimal(0) if value.nil?
          return value if value.is_a?(BigDecimal)

          BigDecimal(value.to_s)
        end
      end
    end
  end
end