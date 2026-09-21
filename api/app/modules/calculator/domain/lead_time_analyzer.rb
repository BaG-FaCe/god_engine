module Calculator
  module Domain
    # Lead time analysis for the material list (Tab 1) and the planner.
    #
    # Pure aggregation over `CostBasis::MaterialLine` values: no queries, no
    # Active Record. The `riskWeightedDays` figure is the one the buyer should
    # plan with - it adds the historical delay risk of the material's risk level
    # on top of the contractual lead time.
    class LeadTimeAnalyzer
      # Extra buffer days applied on top of the planned lead time.
      RISK_BUFFER_DAYS = { 'high' => 14, 'medium' => 7, 'low' => 2, nil => 0 }.freeze

      # Beyond this many days a material counts as "long lead".
      LONG_LEAD_THRESHOLD_DAYS = 60

      Result = Data.define(
        :material_count, :average_planned_days, :longest, :critical_materials,
        :long_lead_count, :average_risk_weighted_days, :buckets, :total_buffer_days
      ) do
        def to_h
          {
            materialCount: material_count,
            averagePlannedDays: average_planned_days,
            averageActualDays: nil,
            longestDays: longest && longest[:days],
            longestMaterial: longest && { id: longest[:id], name: longest[:name] },
            criticalMaterials: critical_materials,
            varianceDays: total_buffer_days,
            riskWeightedAverageDays: average_risk_weighted_days,
            longLeadCount: long_lead_count,
            buckets: buckets
          }
        end
      end

      def initialize(material_lines)
        @material_lines = material_lines
      end

      def call
        return empty_result if material_lines.empty?

        days = material_lines.map { |line| planned_days(line) }
        weighted = material_lines.map { |line| risk_weighted_days(line) }
        longest_line = material_lines.max_by { |line| planned_days(line) }

        Result.new(
          material_count: material_lines.size,
          average_planned_days: average(days),
          longest: longest_line && {
            id: longest_line.id,
            name: longest_line.name,
            days: planned_days(longest_line)
          },
          critical_materials: critical_materials,
          long_lead_count: days.count { |value| value >= LONG_LEAD_THRESHOLD_DAYS },
          average_risk_weighted_days: average(weighted),
          buckets: buckets(days),
          total_buffer_days: weighted.zip(days).sum { |(w, d)| w - d }
        )
      end

      private

      attr_reader :material_lines

      def planned_days(line)
        line.lead_time_days.to_i
      end

      def risk_weighted_days(line)
        planned_days(line) + RISK_BUFFER_DAYS.fetch(line.risk_level, 0)
      end

      # The five materials with the longest lead time - these are the ones that
      # dictate the project timeline.
      def critical_materials
        material_lines
          .sort_by { |line| -risk_weighted_days(line) }
          .first(5)
          .map do |line|
            {
              id: line.id,
              name: line.name,
              leadTimeDays: planned_days(line),
              riskWeightedDays: risk_weighted_days(line),
              riskLevel: line.risk_level
            }
          end
      end

      def buckets(days)
        [
          { label: 'bis 7 Tage', count: days.count { |d| d <= 7 }, thresholdDays: 7 },
          { label: '8-30 Tage', count: days.count { |d| d.between?(8, 30) }, thresholdDays: 30 },
          { label: '31-60 Tage', count: days.count { |d| d.between?(31, 60) }, thresholdDays: 60 },
          { label: 'über 60 Tage', count: days.count { |d| d > 60 }, thresholdDays: nil }
        ]
      end

      def average(values)
        return nil if values.empty?

        (values.sum.to_f / values.size).round(2)
      end

      def empty_result
        Result.new(
          material_count: 0, average_planned_days: nil, longest: nil,
          critical_materials: [], long_lead_count: 0,
          average_risk_weighted_days: nil, buckets: [], total_buffer_days: 0
        )
      end
    end
  end
end