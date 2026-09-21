module SupplyChainRisk
  # Single-material refresh (sync or via Solid Queue / async adapter).
  class RefreshMaterialRiskJob < ApplicationJob
    queue_as :risk_polling

    def perform(material_id, provider_keys = nil)
      material = Material.find(material_id)
      RiskProviderRun.track('manual_refresh', project_id: material.project_id) do |run|
        result = Application::RefreshMaterialRisk.call(material: material, provider_keys: provider_keys)
        run.update!(assessments_written: result.assessments.size)
        result.to_h
      end
    end
  end
end
