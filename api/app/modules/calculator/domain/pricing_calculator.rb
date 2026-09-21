module Calculator
  module Domain
    # The calculation engine itself.
    #
    # Basis of the calculation - one production batch is the costing unit:
    #   * materials -> bill of materials for ONE batch
    #   * labour    -> hours for ONE batch
    #   * monthly   -> period costs spread over `units_per_month`
    #   * fixed     -> one-off costs spread over the batch or the month
    #   * overheads -> percentages on the cost blocks above
    #   * risk      -> percentage surcharge on the subtotal
    #
    # Per-unit values are authoritative: the price is built from them, and the
    # batch / monthly amounts are derived (`per_unit * driver`) so the sheet
    # always adds up in the direction that ends up on the invoice.
    class PricingCalculator
      CATEGORY_LABELS = {
        'material' => 'Materialkosten',
        'monthly' => 'Monatskosten',
        'labor' => 'Fertigungslöhne',
        'fixed' => 'Fixkosten',
        'overhead' => 'Gemeinkosten',
        'risk' => 'Lieferrisiko-Zuschlag',
        'tax' => 'Umsatzsteuer'
      }.freeze

      Result = Data.define(:inputs, :blocks, :lines, :totals, :risk, :taxes, :warnings) do
        def to_h
          {
            inputs: inputs,
            lines: lines.map(&:to_h),
            totals: totals,
            risk: risk,
            taxes: taxes,
            warnings: warnings
          }
        end
      end

      def initialize(basis)
        @basis = basis
      end

      def call
        units = basis.units_per_month
        batch = basis.batch_size

        material = build_material_block(batch)
        labor = build_labor_block(batch)
        fixed = build_fixed_block(batch, units)
        monthly = build_monthly_block(batch, units)

        overhead, risk_from_rules = build_overhead_block(
          batch, material: material, labor: labor, fixed: fixed, monthly: monthly
        )
        risk = build_risk_block(
          batch, subtotal_per_unit([material, labor, fixed, monthly, overhead]), risk_from_rules
        )

        blocks = [material, labor, fixed, monthly, overhead, risk].reject { |b| b.lines.empty? }
        lines = share_lines(blocks.flat_map(&:lines))

        Result.new(
          inputs: basis.inputs.to_h,
          blocks: blocks,
          lines: lines,
          totals: compile_totals(lines, batch, units),
          risk: risk_totals(units),
          taxes: tax_totals,
          warnings: build_warnings(material, units)
        )
      end

      # The resolved risk surcharge policy for this calculation. Public because
      # the application layer reports it back to the UI as the "why".
      def policy
        @policy ||= RiskSurchargePolicy.call(
          aggregate_score: basis.risk.aggregate_score,
          material_count: basis.risk.material_count,
          critical_material_count: basis.risk.critical_material_count,
          single_source_count: basis.risk.single_source_count,
          manual_override: basis.inputs.auto_risk_surcharge ? nil : basis.inputs.risk_surcharge_pct
        )
      end

      private

      attr_reader :basis

      # --- helpers ------------------------------------------------------------

      def per_unit(cents, divisor)
        return 0 if divisor.to_i <= 0

        (Factories.decimal(cents) / Factories.decimal(divisor)).round(0, half: :up).to_i
      end

      def resolve_percentage(rule)
        return Factories.decimal(rule.percentage) unless rule.auto_from_risk
        # An automatic risk rule follows the policy, but a configured non-zero
        # percentage still acts as a floor so a project can never lose its
        # minimum risk margin.
        [policy.applied_pct, Factories.decimal(rule.percentage)].max
      end

      def share_lines(lines)
        total = lines.sum(&:per_unit_cents)
        lines.map do |line|
          share =
            if total.zero?
              BigDecimal(0)
            else
              (Factories.decimal(line.per_unit_cents) / Factories.decimal(total)).round(6)
            end
          line.with(share: share)
        end
      end

      def format_quantity(value)
        decimal = Factories.decimal(value)
        return decimal.to_i.to_s if (decimal % 1).zero?

        format('%.2f', decimal).sub(/0+\z/, '').sub(/\.\z/, '')
      end

      def allocation_label(basis_key)
        {
          'per_unit' => 'je Stück im Batch',
          'per_batch' => 'je Fertigungslos',
          'per_month' => 'je Monat'
        }.fetch(basis_key.to_s, basis_key.to_s)
      end

      # Reuse the decimal coercion from the basis value objects.
      Factories = CostBasis::Factories

      # --- block builders -----------------------------------------------------

      def build_material_block(batch)
        lines = basis.materials.map do |line|
          batch_cents = material_line_cents(line)

          CostBreakdown::CostLine.new(
            key: "material:#{line.id || line.name}",
            label: line.name,
            category: 'material',
            batch_cents: batch_cents,
            per_unit_cents: per_unit(batch_cents, batch),
            share: BigDecimal(0),
            detail: [
              CostBreakdown::Detail.new(
                label: "#{format_quantity(line.quantity)} #{line.unit} × " \
                       "#{line.unit_net_price_cents} ct",
                total_cents: batch_cents,
                per_unit_cents: per_unit(batch_cents, batch)
              )
            ]
          )
        end

        CostBreakdown::Block.new(
          key: 'materials', label: CATEGORY_LABELS['material'],
          category: 'material', lines: lines
        )
      end

      def material_line_cents(line)
        (Factories.decimal(line.quantity) *
         Factories.decimal(line.unit_net_price_cents)).round(0, half: :up).to_i
      end

      def build_labor_block(batch)
        lines = basis.labor_costs.map do |line|
          batch_cents = (Factories.decimal(line.hours) *
                         Factories.decimal(line.hourly_rate_cents)).round(0, half: :up).to_i

          CostBreakdown::CostLine.new(
            key: "labor:#{line.id || line.employee}",
            label: [line.employee, line.role].compact_blank.join(' · '),
            category: 'labor',
            batch_cents: batch_cents,
            per_unit_cents: per_unit(batch_cents, batch),
            share: BigDecimal(0),
            detail: [
              CostBreakdown::Detail.new(
                label: "#{format_quantity(line.hours)} h × #{line.hourly_rate_cents} ct",
                total_cents: batch_cents,
                per_unit_cents: per_unit(batch_cents, batch)
              )
            ]
          )
        end

        CostBreakdown::Block.new(
          key: 'labor', label: CATEGORY_LABELS['labor'], category: 'labor', lines: lines
        )
      end

      def build_fixed_block(batch, units)
        lines = basis.fixed_costs.map do |line|
          divisor = line.allocation_basis.to_s == 'per_month' ? units : batch
          per_unit_cents = per_unit(line.amount_cents, divisor)

          CostBreakdown::CostLine.new(
            key: "fixed:#{line.id || line.name}",
            label: line.name,
            category: 'fixed',
            batch_cents: per_unit_cents * batch,
            per_unit_cents: per_unit_cents,
            share: BigDecimal(0),
            detail: [
              CostBreakdown::Detail.new(
                label: "Verteilung: #{allocation_label(line.allocation_basis)}",
                total_cents: line.amount_cents,
                per_unit_cents: per_unit_cents
              )
            ]
          )
        end

        CostBreakdown::Block.new(
          key: 'fixed', label: CATEGORY_LABELS['fixed'], category: 'fixed', lines: lines
        )
      end

      def build_monthly_block(batch, units)
        lines = basis.monthly_costs.map do |line|
          per_unit_cents = per_unit(line.amount_cents, units)

          CostBreakdown::CostLine.new(
            key: "monthly:#{line.id || line.name}",
            label: line.name,
            category: 'monthly',
            batch_cents: per_unit_cents * batch,
            per_unit_cents: per_unit_cents,
            share: BigDecimal(0),
            detail: [
              CostBreakdown::Detail.new(
                label: "#{line.amount_cents} ct je Monat bei #{units} Stück",
                total_cents: line.amount_cents,
                per_unit_cents: per_unit_cents
              )
            ]
          )
        end

        CostBreakdown::Block.new(
          key: 'monthly', label: CATEGORY_LABELS['monthly'], category: 'monthly', lines: lines
        )
      end

      # Overhead rules are applied sequentially: a rule whose base is `subtotal`
      # sees everything calculated before it, which is how a German
      # Zuschlagskalkulation is built up.
      def build_overhead_block(batch, material:, labor:, fixed:, monthly:)
        direct_cost = material.per_unit_cents + labor.per_unit_cents + fixed.per_unit_cents
        running_subtotal = direct_cost
        risk_from_rules = 0

        lines = basis.overhead_rules
                      .sort_by { |rule| [rule.position.to_i, rule.key.to_s] }
                      .map do |rule|
          base_cents = resolve_base(
            rule.base,
            material: material, labor: labor, fixed: fixed, monthly: monthly,
            direct_cost: direct_cost, subtotal: running_subtotal
          )
          percentage = resolve_percentage(rule)
          per_unit_cents = (Factories.decimal(base_cents) * percentage).round(0, half: :up).to_i
          running_subtotal += per_unit_cents
          risk_from_rules += per_unit_cents if rule.auto_from_risk

          CostBreakdown::CostLine.new(
            key: "overhead:#{rule.key}",
            label: rule.name,
            category: 'overhead',
            batch_cents: per_unit_cents * batch,
            per_unit_cents: per_unit_cents,
            share: BigDecimal(0),
            detail: [
              CostBreakdown::Detail.new(
                label: "#{format_percentage(percentage)} auf #{base_label(rule.base)}",
                total_cents: base_cents,
                per_unit_cents: per_unit_cents
              )
            ]
          )
        end

        [
          CostBreakdown::Block.new(
            key: 'overhead', label: CATEGORY_LABELS['overhead'],
            category: 'overhead', lines: lines
          ),
          risk_from_rules
        ]
      end

      # The dedicated risk line is only added when no overhead rule already
      # carries the surcharge - that way the price never contains it twice.
      def build_risk_block(batch, subtotal, risk_from_rules)
        lines = []

        if risk_from_rules.zero? && basis.inputs.auto_risk_surcharge &&
           policy.applied_pct.positive?
          per_unit_cents = (Factories.decimal(subtotal) * policy.applied_pct)
                           .round(0, half: :up).to_i
          lines << CostBreakdown::CostLine.new(
            key: 'risk:surcharge',
            label: CATEGORY_LABELS['risk'],
            category: 'risk',
            batch_cents: per_unit_cents * batch,
            per_unit_cents: per_unit_cents,
            share: BigDecimal(0),
            detail: [
              CostBreakdown::Detail.new(
                label: "#{format_percentage(policy.applied_pct)} auf Zwischensumme " \
                       "(Score #{basis.risk.aggregate_score})",
                total_cents: subtotal,
                per_unit_cents: per_unit_cents
              )
            ]
          )
        end

        CostBreakdown::Block.new(
          key: 'risk', label: CATEGORY_LABELS['risk'], category: 'risk', lines: lines
        )
      end

      def resolve_base(base, material:, labor:, fixed:, monthly:, direct_cost:, subtotal:)
        case base.to_s
        when 'materials' then material.per_unit_cents
        when 'labor' then labor.per_unit_cents
        when 'fixed_costs' then fixed.per_unit_cents
        when 'monthly_costs' then monthly.per_unit_cents
        when 'direct_cost' then direct_cost
        when 'subtotal' then subtotal
        else direct_cost
        end
      end

      def base_label(base)
        {
          'materials' => 'Materialkosten',
          'labor' => 'Fertigungslöhnen',
          'fixed_costs' => 'Fixkosten',
          'monthly_costs' => 'Monatskosten',
          'direct_cost' => 'direkten Kosten',
          'subtotal' => 'Zwischensumme'
        }.fetch(base.to_s, base.to_s)
      end

      def subtotal_per_unit(blocks)
        blocks.sum(&:per_unit_cents)
      end

      def format_percentage(fraction)
        format('%.2f %%', Factories.decimal(fraction) * 100)
      end

      # --- totals -------------------------------------------------------------

      # Per-unit values are authoritative; the monthly figures are derived from
      # them so the invoice line and the monthly report can never disagree.
      def compile_totals(lines, batch, units)
        per_unit_by_category = lines.group_by(&:category).transform_values do |group|
          group.sum(&:per_unit_cents)
        end

        material = per_unit_by_category.fetch('material', 0)
        monthly = per_unit_by_category.fetch('monthly', 0)
        labor = per_unit_by_category.fetch('labor', 0)
        fixed = per_unit_by_category.fetch('fixed', 0)
        overhead = per_unit_by_category.fetch('overhead', 0)
        risk = per_unit_by_category.fetch('risk', 0)

        direct_cost = material + labor + fixed
        per_unit_net = direct_cost + monthly + overhead + risk
        per_unit_tax = (Factories.decimal(per_unit_net) * basis.tax_rate).round(0, half: :up).to_i
        per_unit_gross = per_unit_net + per_unit_tax

        {
          materialCostCents: material * units,
          monthlyCostCents: monthly * units,
          laborCostCents: labor * units,
          fixedCostCents: fixed * units,
          directCostCents: direct_cost * units,
          overheadCents: overhead * units,
          riskSurchargeCents: risk * units,
          totalCostNetCents: per_unit_net * units,
          taxCents: per_unit_tax * units,
          totalCostGrossCents: per_unit_gross * units,
          perUnitNetCents: per_unit_net,
          perUnitGrossCents: per_unit_gross,
          perUnitTaxCents: per_unit_tax,
          perUnitMaterialCents: material,
          perUnitMonthlyCents: monthly,
          perUnitLaborCents: labor,
          perUnitFixedCents: fixed,
          perUnitOverheadCents: overhead,
          perUnitRiskSurchargeCents: risk,
          batchCostNetCents: per_unit_net * batch,
          unitsPerMonth: units,
          batchSize: batch
        }
      end

      def risk_totals(_units)
        {
          aggregateScore: basis.risk.aggregate_score,
          level: policy.level,
          suggestedSurchargePct: policy.suggested_pct.to_f.round(6),
          appliedSurchargePct: policy.applied_pct.to_f.round(6),
          baseSurchargePct: policy.base_pct.to_f.round(6),
          criticalBonusPct: policy.critical_bonus_pct.to_f.round(6),
          singleSourceBonusPct: policy.single_source_bonus_pct.to_f.round(6),
          criticalMaterialCount: basis.risk.critical_material_count,
          singleSourceCount: basis.risk.single_source_count,
          materialCount: basis.risk.material_count,
          maxSurchargePct: RiskSurchargePolicy.max_surcharge.to_f.round(6),
          reason: policy.reason,
          source: policy.source,
          dataSources: basis.risk.data_sources
        }
      end

      def tax_totals
        {
          taxRate: basis.tax_rate.to_f.round(6),
          taxProfile: basis.inputs.tax_profile || 'standard',
          country: basis.inputs.country || 'DE',
          taxExempt: basis.inputs.tax_exempt ? true : false
        }
      end

      def build_warnings(material_block, units)
        warnings = []
        warnings << 'Es sind keine Materialien erfasst - die Kalkulation basiert nur auf Kostenblöcken.' if basis.materials.empty?
        warnings << 'Es sind keine Monatskosten erfasst.' if basis.monthly_costs.empty?
        if !basis.risk.has_data?
          warnings << 'Für dieses Projekt liegen keine Risikodaten vor; es wurde kein Risikozuschlag berechnet.'
        elsif RiskSurchargePolicy.significant?(policy.applied_pct)
          warnings << format(
            'Der Lieferrisiko-Zuschlag beträgt %.2f %% und ist im Preis enthalten.',
            policy.applied_pct * 100
          )
        end
        warnings << 'Die Menge je Monat ist 1 - Fixkosten je Monat werden nicht aufgeteilt.' if units == 1 && basis.monthly_costs.any?
        warnings
      end
    end
  end
end