module Api
  module V1
    class SalesForecastsController < ApplicationController
      before_action :set_project

      # GET /api/v1/projects/:project_id/sales_forecasts/analysis
      def analysis
        rows = @project.sales_forecasts.ordered.to_a
        total_forecast = rows.sum(&:forecast_units)
        total_actual = rows.sum { |row| row.actual_units || 0 }
        render json: {
          rows: rows.map do |row|
            { period: row.period, forecastUnits: row.forecast_units,
              actualUnits: row.actual_units, deviationUnits: row.deviation_units,
              deviationPct: row.deviation_pct }
          end,
          totals: {
            forecastUnits: total_forecast, actualUnits: total_actual,
            deviationUnits: total_actual - total_forecast,
            deviationPct: total_forecast.zero? ? nil : (total_actual - total_forecast).to_f / total_forecast,
            monthsWithActuals: rows.count { |row| !row.actual_units.nil? }
          },
          profitDeviationCents: nil, costPerUnitCents: nil
        }
      end

      private

      def set_project
        @project = Project.find(params[:project_id])
      end
    end
  end
end
