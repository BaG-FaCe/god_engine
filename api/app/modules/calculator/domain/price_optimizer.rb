module Calculator
  module Domain
    # "Preisoptimierung" - evaluates a target selling price chosen by the user.
    #
    # The calculator answers "what does the product cost?", this class answers
    # "what happens if we sell it at X?". Keeping the two apart means the
    # optimisation can be re-run for many target prices without recalculating the
    # cost basis, which is what makes the interactive slider in the UI cheap.
    class PriceOptimizer
      Factories = CostBasis::Factories

      Result = Data.define(
        :target, :calculated, :profit, :revenue, :monthly_profit, :break_even,
        :variable_cost, :fixed_cost, :warnings
      ) do
        def to_h
          {
            target: target,
            calculated: calculated,
            profit: profit,
            revenue: revenue,
            monthlyProfit: monthly_profit,
            breakEven: break_even,
            variableCost: variable_cost,
            fixedCost: fixed_cost,
            warnings: warnings
          }
        end
      end

      def initialize(basis:, totals:)
        @basis = basis
        @totals = totals
      end

      # @param target_price_cents [Integer] the price the user wants to test
      # @param includes_tax [Boolean] whether that price is gross or net
      def call(target_price_cents:, includes_tax:, units_per_month: nil, batch_size: nil)
        units = resolve_units(units_per_month)
        batch = resolve_batch(batch_size)

        price = Factories.decimal(target_price_cents).round(0, half: :up).to_i
        tax_rate = basis.tax_rate

        net, gross =
          if includes_tax
            [net_from_gross(price, tax_rate), price]
          else
            [price, gross_from_net(price, tax_rate)]
          end

        cost_net = totals[:perUnitNetCents].to_i
        cost_gross = totals[:perUnitGrossCents].to_i
        variable_cost = variable_cost_per_unit
        fixed_cost = fixed_cost_cents_per_month
        contribution = net - variable_cost

        Result.new(
          target: {
            priceCents: price,
            includesTax: includes_tax ? true : false,
            netCents: net,
            grossCents: gross
          },
          calculated: { netCents: cost_net, grossCents: cost_gross },
          profit: profit_block(net, gross, cost_net, variable_cost, contribution),
          revenue: {
            monthlyNetCents: net * units,
            monthlyGrossCents: gross * units,
            batchNetCents: net * batch,
            batchGrossCents: gross * batch
          },
          monthly_profit: monthly_profit_block(net, cost_net, units),
          break_even: break_even_block(contribution, fixed_cost, units),
          variable_cost: {
            perUnitCents: variable_cost,
            shareOfPricePct: net.zero? ? nil : (variable_cost.to_f / net).round(6)
          },
          fixed_cost: {
            perMonthCents: fixed_cost,
            perUnitAtVolumeCents: units.positive? ? (fixed_cost / units).round : 0
          },
          warnings: build_warnings(net, cost_net, contribution, units)
        )
      end

      private

      attr_reader :basis, :totals

      def resolve_units(units_per_month)
        units = units_per_month.to_i
        units.positive? ? units : basis.units_per_month
      end

      def resolve_batch(batch_size)
        batch = batch_size.to_i
        batch.positive? ? batch : basis.batch_size
      end

      def profit_block(net, gross, cost_net, variable_cost, contribution)
        profit_per_unit = net - cost_net

        {
          perUnitNetCents: profit_per_unit,
          perUnitGrossCents: gross - totals[:perUnitGrossCents].to_i,
          marginPct: net.zero? ? nil : (profit_per_unit.to_f / net).round(6),
          markupPct: cost_net.zero? ? nil : (profit_per_unit.to_f / cost_net).round(6),
          contributionMarginPerUnitCents: contribution,
          contributionMarginRatioPct: net.zero? ? nil : (contribution.to_f / net).round(6),
          variableCostPerUnitCents: variable_cost,
          fullCostPerUnitCents: cost_net
        }
      end

      def monthly_profit_block(net, cost_net, units)
        profit_per_unit = net - cost_net

        {
          netCents: profit_per_unit * units,
          marginPct: net.zero? ? nil : (profit_per_unit.to_f / net).round(6),
          unitsPerMonth: units
        }
      end

      # Break-even in units: how many units must be sold per month to cover the
      # period fixed costs at the tested price.
      def break_even_block(contribution, fixed_cost, units)
        if contribution <= 0
          return {
            unitsPerMonth: nil,
            revenueNetCents: nil,
            feasible: false,
            reason: 'Der Deckungsbeitrag je Stück ist null oder negativ - die ' \
                    'Fixkosten können bei diesem Preis nicht gedeckt werden.'
          }
        end

        units_needed = (Factories.decimal(fixed_cost) / Factories.decimal(contribution)).ceil
        {
          unitsPerMonth: units_needed,
          revenueNetCents: units_needed * contribution,
          feasible: units_needed <= units,
          coverageRatioPct: units.zero? ? nil : (units.to_f / units_needed).round(4),
          currentVolume: units
        }
      end

      # Everything except the period (monthly) and project fixed cost blocks is
      # proportional to the produced quantity in this model.
      def variable_cost_per_unit
        totals[:perUnitNetCents].to_i -
          totals[:perUnitMonthlyCents].to_i -
          totals[:perUnitFixedCents].to_i
      end

      def fixed_cost_cents_per_month
        monthly = basis.monthly_costs.sum { |line| line.amount_cents.to_i }
        per_month_fixed = basis.fixed_costs
                               .select { |line| line.allocation_basis.to_s == 'per_month' }
                               .sum { |line| line.amount_cents.to_i }
        monthly + per_month_fixed
      end

      def net_from_gross(gross_cents, tax_rate)
        denominator = BigDecimal(1) + tax_rate
        return gross_cents if denominator.zero?

        (Factories.decimal(gross_cents) / denominator).round(0, half: :up).to_i
      end

      def gross_from_net(net_cents, tax_rate)
        (Factories.decimal(net_cents) * (BigDecimal(1) + tax_rate)).round(0, half: :up).to_i
      end

      def build_warnings(net, cost_net, contribution, units)
        warnings = []

        if net < cost_net
          warnings << format('Der Zielpreis liegt %d ct unter den Selbstkosten je Stück.',
                             cost_net - net)
        end

        if contribution <= 0
          warnings << 'Der Deckungsbeitrag ist nicht positiv - jeder zusätzliche ' \
                      'Verkauf erhöht den Verlust.'
        else
          fixed = fixed_cost_cents_per_month
          if fixed.positive?
            break_even_units =
              (Factories.decimal(fixed) / Factories.decimal(contribution)).ceil
            if break_even_units > units
              warnings << format(
                'Die Gewinnschwelle liegt bei %d Stück je Monat, geplant sind %d Stück.',
                break_even_units, units
              )
            end
          end
        end

        if basis.risk.aggregate_score.nil?
          warnings << 'Ohne Risikodaten kann der Risikozuschlag den Preis nicht absichern.'
        end

        warnings
      end
    end
  end
end