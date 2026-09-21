module Api
  module V1
    # Tab 4 — full price calculation + target-price optimisation.
    class PricingController < ApplicationController
      before_action :set_project

      # GET /api/v1/projects/:project_id/pricing
      def show
        basis = Calculator::Application::BuildCostBasis.call(
          project: @project,
          units_per_month: params[:unitsPerMonth], batch_size: params[:batchSize]
        )
        result = Calculator::Domain::PricingCalculator.new(basis).call
        render json: serialize_result(result)
      end

      # POST /api/v1/projects/:project_id/pricing/optimize
      def optimize
        basis = Calculator::Application::BuildCostBasis.call(project: @project)
        totals = Calculator::Domain::PricingCalculator.new(basis).call.totals
        optimizer = Calculator::Domain::PriceOptimizer.new(basis: basis, totals: totals)
        result = optimizer.call(
          target_price_cents: params.require(:targetPriceCents).to_i,
          includes_tax: params[:targetPriceIncludesTax] != false,
          units_per_month: params[:unitsPerMonth], batch_size: params[:batchSize]
        )
        render json: result.to_h
      end

      private

      def set_project
        @project = Project.find(params[:project_id])
      end

      def serialize_result(result)
        hash = result.to_h
        hash[:blocks] = result.blocks.map do |block|
          { key: block.key, label: block.label, category: block.category,
            lines: block.lines.map(&:to_h) }
        end
        hash
      end
    end
  end
end
