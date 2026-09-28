module Calculator
  module Application
    # Deep copy of a project (materials + costs + rules + forecasts + risk profiles).
    class DuplicateProject
      class << self
        def call(project:)
          Project.transaction do
            copy = project.dup
            copy.name = "#{project.name} (Kopie)"
            copy.status = 'draft'
            copy.archived_at = nil
            copy.save!

            project.suppliers.find_each do |supplier|
              dup_record(supplier, project_id: copy.id)
            end
            supplier_map = map_ids(project.suppliers, copy.suppliers)

            project.materials.includes(:material_risk_profile, :alternative_suppliers).find_each do |material|
              material_copy = dup_record(material, project_id: copy.id,
                                                   supplier_id: supplier_map[material.supplier_id])
              if material.material_risk_profile
                dup_record(material.material_risk_profile, material_id: material_copy.id)
              end
              material.alternative_suppliers.each do |alt|
                dup_record(alt, material_id: material_copy.id)
              end
            end

            %i[monthly_costs labor_costs fixed_costs overhead_rules sales_forecasts].each do |assoc|
              project.public_send(assoc).find_each { |row| dup_record(row, project_id: copy.id) }
            end

            # Pricing scenarios carry a 1:1 result + warnings (formerly the
            # `result_snapshot` JSON column), which must be copied explicitly.
            project.pricing_scenarios.find_each do |scenario|
              copy_scenario = dup_record(scenario, project_id: copy.id)
              next unless scenario.result

              copy_result = dup_record(scenario.result, pricing_scenario_id: copy_scenario.id)
              scenario.result.warnings.each do |warning|
                dup_record(warning, pricing_scenario_result_id: copy_result.id)
              end
            end

            copy
          end
        end

        private

        def dup_record(record, overrides = {})
          copy = record.dup
          overrides.each { |key, value| copy.public_send("#{key}=", value) }
          copy.save!
          copy
        end

        def map_ids(originals, copies)
          original_ids = originals.map(&:id)
          copy_ids = copies.order(:created_at).map(&:id)
          original_ids.zip(copy_ids).to_h
        end
      end
    end
  end
end
