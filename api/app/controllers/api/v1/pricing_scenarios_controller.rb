module Api
  module V1
    class PricingScenariosController < ApplicationController
      before_action :authenticate_user!, except: %i[index show]
      before_action :set_project
      before_action :set_scenario, only: %i[show update destroy activate optimize]

      def index
        render json: {
          data: @project.pricing_scenarios.ordered.map do |s|
            Calculator::Application::Serializers.pricing_scenario(s)
          end
        }
      end

      def show
        render json: Calculator::Application::Serializers.pricing_scenario(@scenario)
      end

      def create
        require_write!
        scenario = @project.pricing_scenarios.new(scenario_params)
        scenario.save!
        audit('create', auditable: scenario, project: @project)
        render json: Calculator::Application::Serializers.pricing_scenario(scenario), status: :created
      end

      def update
        require_write!
        @scenario.update!(scenario_params)
        audit('update', auditable: @scenario, project: @project)
        render json: Calculator::Application::Serializers.pricing_scenario(@scenario)
      end

      def destroy
        require_write!
        audit('delete', auditable: @scenario, project: @project)
        @scenario.destroy!
        head :no_content
      end

      def activate
        require_write!
        @scenario.activate!
        render json: Calculator::Application::Serializers.pricing_scenario(@scenario)
      end

      def optimize
        basis = Calculator::Application::BuildCostBasis.call(project: @project)
        totals = Calculator::Domain::PricingCalculator.new(basis).call.totals
        result = Calculator::Domain::PriceOptimizer.new(basis: basis, totals: totals).call(
          target_price_cents: @scenario.target_price_cents || params[:targetPriceCents].to_i,
          includes_tax: @scenario.target_price_includes_tax,
          units_per_month: @scenario.units_per_month, batch_size: @scenario.batch_size
        )
        @scenario.update!(result_snapshot: result.to_h)
        render json: result.to_h
      end

      private

      def set_project
        @project = Project.find(params[:project_id])
      end

      def set_scenario
        @scenario = @project.pricing_scenarios.find(params[:id])
      end

      def scenario_params
        params.require(:pricing_scenario).permit(
          :name, :target_price_cents, :target_price_includes_tax,
          :units_per_month, :batch_size, :is_active, :notes
        )
      end
    end
  end
end
