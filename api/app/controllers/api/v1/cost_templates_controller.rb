module Api
  module V1
    class CostTemplatesController < ApplicationController
      before_action :authenticate_user!, except: %i[index show]

      def index
        scope = CostTemplate.ordered
        scope = scope.for_project(Project.find_by(id: params[:projectId])) if params[:projectId]
        render json: {
          data: scope.map { |t| Calculator::Application::Serializers.cost_template(t) }
        }
      end

      def show
        render json: Calculator::Application::Serializers.cost_template(CostTemplate.find(params[:id]))
      end

      def create
        require_write!
        template = CostTemplate.new(template_params)
        template.save!
        render json: Calculator::Application::Serializers.cost_template(template), status: :created
      end

      def update
        require_write!
        template = CostTemplate.find(params[:id])
        template.update!(template_params)
        render json: Calculator::Application::Serializers.cost_template(template)
      end

      def destroy
        require_write!
        CostTemplate.find(params[:id]).destroy!
        head :no_content
      end

      def apply
        require_write!
        template = CostTemplate.find(params[:id])
        project = Project.find(params[:projectId])
        summary = Calculator::Application::ApplyCostTemplate.call(project: project, template: template)
        audit('import', auditable: project, project: project, metadata: summary)
        render json: summary
      end

      private

      def template_params
        params.require(:cost_template).permit(:name, :kind, :description, :is_global,
                                              :project_id, items: [])
      end
    end
  end
end
