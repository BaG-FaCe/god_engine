module Calculator
  module Domain
    # Value objects of a price calculation.
    #
    # Everything here is an immutable `Data` instance - no Active Record, no
    # Rails. That is what makes `PricingCalculator` unit-testable without a
    # database and reusable if the context is extracted into its own service.
    module CostBreakdown
      # One row in the calculation sheet.
      CostLine = Data.define(
        :key, :label, :category, :batch_cents, :per_unit_cents, :share, :detail
      ) do
        def total_cents
          batch_cents
        end

        def to_h
          {
            key: key,
            label: label,
            category: category,
            totalCents: batch_cents,
            perUnitCents: per_unit_cents,
            share: share,
            detail: detail
          }
        end
      end

      Detail = Data.define(:label, :total_cents, :per_unit_cents) do
        def to_h
          { label: label, totalCents: total_cents, perUnitCents: per_unit_cents }
        end
      end

      # A named group of lines (materials, labour, overheads, ...).
      Block = Data.define(:key, :label, :category, :lines) do
        def batch_cents
          lines.sum(&:batch_cents)
        end

        def per_unit_cents
          lines.sum(&:per_unit_cents)
        end
      end

      # Base class for every "cost basis" the calculator consumes.
      #
      # A basis is a plain, pre-loaded snapshot of one project. Loading it is the
      # job of the application layer (`Calculator::Application::BuildCostBasis`),
      # which also means the calculator itself never issues a query.
      module Basis
      end
    end
  end
end