require 'csv'

module Calculator
  module Application
    # Minimal CSV export for materials (full XLSX/PDF via caxlsx/prawn follow).
    module ProjectCsv
      class << self
        def export(project)
          CSV.generate(headers: true, col_sep: ';') do |csv|
            csv << %w[id name supplier article_number unit_price_cents quantity
                      lead_time_days risk_score risk_level]
            project.materials.ordered.each do |material|
              csv << [material.id, material.name, material.supplier&.name,
                      material.article_number, material.unit_price_cents,
                      material.quantity.to_s, material.lead_time_days,
                      material.risk_score, material.risk_level]
            end
          end
        end
      end
    end
  end
end
