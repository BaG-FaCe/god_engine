module Api
  module V1
    class ProjectsController < ApplicationController
      before_action :authenticate_user!, except: %i[index show]
      before_action :set_project, only: %i[show update destroy duplicate archive restore export import]

      # GET /api/v1/projects
      def index
        scope = Project.ordered.search(params[:q])
        scope = scope.where(status: params[:status]) if params[:status].present?
        total = scope.count
        pagination = pagination_params
        records = scope.offset((pagination[:page] - 1) * pagination[:per_page]).limit(pagination[:per_page])
        render_paginated(
          records, total: total, page: pagination[:page], per_page: pagination[:per_page],
          serializer: Calculator::Application::Serializers.method(:project)
        )
      end

      # GET /api/v1/projects/:id
      def show
        render json: Calculator::Application::Serializers.project(@project)
      end

      # POST /api/v1/projects
      def create
        require_write!
        project = Project.new(project_params)
        project.owner = current_user
        project.save!
        OverheadRule::DEFAULT_RULES.each { |rule| project.overhead_rules.create!(rule) }
        audit('create', auditable: project, project: project)
        render json: Calculator::Application::Serializers.project(project), status: :created
      end

      # PATCH /api/v1/projects/:id
      def update
        require_write!
        @project.update!(project_params)
        audit('update', auditable: @project, project: @project)
        render json: Calculator::Application::Serializers.project(@project)
      end

      # DELETE /api/v1/projects/:id
      def destroy
        require_write!
        audit('delete', auditable: @project, project: @project)
        @project.destroy!
        head :no_content
      end

      # POST /api/v1/projects/:id/duplicate
      def duplicate
        require_write!
        copy = Calculator::Application::DuplicateProject.call(project: @project)
        audit('create', auditable: copy, project: copy, metadata: { source: @project.id })
        render json: Calculator::Application::Serializers.project(copy), status: :created
      end

      # POST /api/v1/projects/:id/archive / restore
      def archive
        require_write!
        @project.archive!
        audit('archive', auditable: @project, project: @project)
        render json: Calculator::Application::Serializers.project(@project)
      end

      def restore
        require_write!
        @project.restore!
        audit('restore', auditable: @project, project: @project)
        render json: Calculator::Application::Serializers.project(@project)
      end

      # GET /api/v1/projects/:id/export?format=json|csv
      def export
        format = params[:format].presence || 'json'
        unless %w[json csv].include?(format)
          return render_error("Exportformat '#{format}' wird von diesem Endpunkt nicht unterstützt",
                              code: 'unsupported_format', status: :not_acceptable)
        end

        audit('export', auditable: @project, project: @project, metadata: { format: format })

        if format == 'csv'
          send_data Calculator::Application::ProjectCsv.export(@project),
                    filename: "#{@project.name.parameterize}.csv", type: 'text/csv'
        else
          render json: Calculator::Application::ProjectDocument.build(project: @project)
        end
      end

      # POST /api/v1/projects/:id/import (project JSON document in body)
      def import
        require_write!
        counts = Calculator::Application::ProjectDocument.apply!(project: @project, document: params.permit!.to_h)
        audit('import', auditable: @project, project: @project, metadata: counts)
        render json: { imported: counts }
      end

      private

      def set_project
        @project = Project.find(params[:id])
      end

      def project_params
        params.require(:project).permit(
          :name, :description, :status, :tax_rate, :tax_profile, :country, :currency,
          :units_per_month, :batch_size, :target_margin_pct, :risk_surcharge_pct,
          :auto_risk_surcharge, :risk_refresh_interval_hours
        )
      end
    end
  end
end
