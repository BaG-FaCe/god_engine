module SupplyChainRisk
  # Bulk refresh of all stale materials (every 12h per recurring.yml).
  class RefreshRiskAssessmentsJob < ApplicationJob
    queue_as :risk_polling

    def perform(project_id = nil)
      scope = Material.includes(:project, :material_risk_profile)
      scope = scope.where(project_id: project_id) if project_id
      refreshed = 0
      scope.find_each do |material|
        next if material.last_risk_checked_at &&
                material.last_risk_checked_at > material.project.risk_refresh_interval_hours.hours.ago

        Application::RefreshMaterialRisk.call(material: material)
        refreshed += 1
      end
      refreshed
    end
  end
end
