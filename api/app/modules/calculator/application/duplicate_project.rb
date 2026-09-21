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

            %i[monthly_costs labor_costs fixed_costs overhead_rules sales_forecasts pricing_scenarios].each do |assoc|
              project.public_send(assoc).find_each { |row| dup_record(row, project_id: copy.id) }
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
