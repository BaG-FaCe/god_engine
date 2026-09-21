module Api
  module V1
    class SuppliersController < ApplicationController
      before_action :authenticate_user!, except: %i[index show]
      before_action :set_project
      before_action :set_supplier, only: %i[show update destroy]

      def index
        scope = @project.suppliers.ordered.search rescue @project.suppliers.ordered
        scope = scope.search(params[:q]) if params[:q].present?
        render json: { data: scope.map { |s| Calculator::Application::Serializers.supplier(s) } }
      end

      def show
        render json: Calculator::Application::Serializers.supplier(@supplier)
      end

      def create
        require_write!
        supplier = @project.suppliers.new(supplier_params)
        supplier.save!
        audit('create', auditable: supplier, project: @project)
        render json: Calculator::Application::Serializers.supplier(supplier), status: :created
      end

      def update
        require_write!
        @supplier.update!(supplier_params)
        audit('update', auditable: @supplier, project: @project)
        render json: Calculator::Application::Serializers.supplier(@supplier)
      end

      def destroy
        require_write!
        audit('delete', auditable: @supplier, project: @project)
        @supplier.destroy!
        head :no_content
      end

      private

      def set_project
        @project = Project.find(params[:project_id])
      end

      def set_supplier
        @supplier = @project.suppliers.find(params[:id])
      end

      def supplier_params
        params.require(:supplier).permit(
          :name, :country, :city, :contact_name, :contact_email, :contact_phone,
          :website, :rating, :is_single_source, :notes
        )
      end
    end
  end
end
