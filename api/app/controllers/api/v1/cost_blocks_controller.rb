module Api
  module V1
    # Generic CRUD for the cost blocks (monthly / labor / fixed / overhead /
    # forecasts / scenarios / suppliers / templates). One controller keeps the
    # surface small; the type is resolved from the route.
    class CostBlocksController < ApplicationController
      before_action :authenticate_user!, except: %i[index]
      before_action :set_project

      MODEL = {
        'monthly_costs' => MonthlyCost,
        'labor_costs' => LaborCost,
        'fixed_costs' => FixedCost,
        'overhead_rules' => OverheadRule,
        'sales_forecasts' => SalesForecast,
        'pricing_scenarios' => PricingScenario,
        'suppliers' => Supplier,
        'cost_templates' => CostTemplate
      }.freeze

      def index
        scope = association_scope.ordered rescue association_scope
        total = scope.count
        pagination = pagination_params
        records = scope.offset((pagination[:page] - 1) * pagination[:per_page]).limit(pagination[:per_page])
        render json: {
          data: records.map { |record| serialize(record) },
          meta: { page: pagination[:page], perPage: pagination[:per_page], total: total,
                  totalPages: (total.to_f / pagination[:per_page]).ceil }
        }
      end

      def create
        require_write!
        record = association_scope.new(create_params)
        record.save!
        audit('create', auditable: record, project: @project)
        render json: serialize(record), status: :created
      end

      def update
        require_write!
        record = association_scope.find(params[:id])
        record.update!(create_params)
        audit('update', auditable: record, project: @project)
        render json: serialize(record)
      end

      def destroy
        require_write!
        record = association_scope.find(params[:id])
        audit('delete', auditable: record, project: @project)
        record.destroy!
        head :no_content
      end

      private

      def set_project
        @project = Project.find(params[:project_id])
      end

      def block_key
        params[:block] || controller_name
      end

      def model_class
        MODEL.fetch(block_key) { raise ActiveRecord::RecordNotFound, "Unbekannter Block #{block_key}" }
      end

      def association_scope
        @project.public_send(block_key)
      end

      def create_params
        params.require(:item).permit!
      end

      def serialize(record)
        key = block_key.singularize
        serializer = Calculator::Application::Serializers
        case key
        when 'monthly_cost' then serializer.monthly_cost(record)
        when 'labor_cost' then serializer.labor_cost(record)
        when 'fixed_cost' then serializer.fixed_cost(record)
        when 'overhead_rule' then serializer.overhead_rule(record)
        when 'sales_forecast' then serializer.sales_forecast(record)
        when 'pricing_scenario' then serializer.pricing_scenario(record)
        when 'supplier' then serializer.supplier(record)
        when 'cost_template' then serializer.cost_template(record)
        else record.as_json
        end
      end
    end
  end
end
