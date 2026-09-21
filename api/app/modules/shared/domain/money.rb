module Shared
  module Domain
    # Immutable wrapper around, and normaliser for, all monetary values.
    #
    # Money is stored and transported as **integer cents**. Converting early
    # avoids binary floating point drift: `0.1 + 0.2 != 0.3` in Float, but
    # `10 + 20 == 30` in cents.
    #
    # Rounding uses `:half_up` (commercial rounding) which is what an auditor
    # expects on an invoice, in contrast to Ruby's default banker's rounding.
    class Money
      include Comparable

      CENTS_PER_UNIT = 100

      attr_reader :cents, :currency

      class << self
        # Accepts Integer cents, BigDecimal, Float or a numeric String.
        def from(input, currency: 'EUR')
          return input if input.is_a?(Money)

          new(to_cents(input), currency: currency)
        end

        def to_cents(input)
          case input
          when nil then 0
          when Integer then input
          when BigDecimal then (input * CENTS_PER_UNIT).round(0, half: :up).to_i
          when Rational then (input * CENTS_PER_UNIT).round(0, half: :up).to_i
          when Float then (BigDecimal(input.to_s) * CENTS_PER_UNIT).round(0, half: :up).to_i
          when String then to_cents(BigDecimal(input))
          else
            raise ArgumentError, "Cannot convert #{input.class} to Money"
          end
        end

        def zero(currency = 'EUR')
          new(0, currency: currency)
        end

        # Applies a decimal fraction (0.19 = 19 %) to a cent amount.
        def percentage_of(cents, fraction)
          return 0 if cents.zero? || fraction.nil? || fraction.to_f.zero?

          ratio = fraction.is_a?(BigDecimal) ? fraction : BigDecimal(fraction.to_s)
          (BigDecimal(cents.to_s) * ratio).round(0, half: :up).to_i
        end

        # Allocates `total_cents` over `weights` without losing a single cent.
        # The rounding remainder is distributed to the largest fractional parts
        # (largest remainder method), so the parts always sum back to the total.
        def allocate(total_cents, weights)
          total = total_cents.to_i
          return [] if weights.empty?
          return weights.map { 0 } if total.zero?

          weight_sum = weights.sum
          return weights.map { |_| 0 } if weight_sum.zero?

          exact = weights.map { |w| BigDecimal(total.to_s) * BigDecimal(w.to_s) / BigDecimal(weight_sum.to_s) }
          floored = exact.map { |value| value.floor.to_i }
          remainder = total - floored.sum

          order = exact.each_with_index.sort_by { |(value, index)| [-value.frac, index] }
          order.first(remainder).each { |(_, index)| floored[index] += 1 }
          floored
        end
      end

      def initialize(cents, currency: 'EUR')
        @cents = cents.to_i
        @currency = currency
        freeze
      end

      def +(other)
        self.class.new(cents + coerce_cents(other), currency: currency)
      end

      def -(other)
        self.class.new(cents - coerce_cents(other), currency: currency)
      end

      def *(factor)
        ratio = factor.is_a?(BigDecimal) ? factor : BigDecimal(factor.to_s)
        self.class.new((BigDecimal(cents.to_s) * ratio).round(0, half: :up).to_i, currency: currency)
      end

      def /(divisor)
        raise ZeroDivisionError, 'Money cannot be divided by zero' if divisor.to_f.zero?

        ratio = BigDecimal(divisor.to_s)
        self.class.new((BigDecimal(cents.to_s) / ratio).round(0, half: :up).to_i, currency: currency)
      end

      def <=>(other)
        cents <=> coerce_cents(other)
      end

      def zero?
        cents.zero?
      end

      def negative?
        cents.negative?
      end

      def positive?
        cents.positive?
      end

      def to_f
        cents / CENTS_PER_UNIT.to_f
      end

      def to_d
        BigDecimal(cents.to_s) / CENTS_PER_UNIT
      end

      def to_i
        cents
      end

      # `#as_json` returning the integer keeps the JSON contract stable.
      def as_json(*)
        cents
      end

      def to_s
        format('%.2f %s', to_f, currency)
      end

      def inspect
        "#<#{self.class} #{to_s}>"
      end

      private

      # Allows `money + 500` (raw cents) as well as `money + Money`.
      def coerce_cents(other)
        other.is_a?(Money) ? other.cents : self.class.to_cents(other)
      end
    end
  end
end