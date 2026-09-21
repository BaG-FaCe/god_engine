module Calculator
  module Application
    # Portable JSON project document (deliverable 3, `supplyChainRisk` block).
    module ProjectDocument
      SCHEMA_VERSION = '1.0'.freeze

      class << self
        def build(project:)
          project = Project.includes(
            :suppliers, materials: %i[supplier material_risk_profile alternative_suppliers]
          ).find(project.id)

          {
            schemaVersion: SCHEMA_VERSION,
            projectName: project.name,
            exportedAt: Time.current.iso8601,
            country: project.country, currency: project.currency,
            taxRate: project.tax_rate.to_f, taxProfile: project.tax_profile,
            materials: project.materials.map { |material| material_entry(material) },
            suppliers: project.suppliers.map { |supplier| supplier_entry(supplier) },
            monthlyCosts: project.monthly_costs.map do |row|
              { category: row.category, name: row.name, amountCents: row.amount_cents,
                isRecurring: row.is_recurring, notes: row.notes }
            end,
            fixedCosts: project.fixed_costs.map do |row|
              { category: row.category, name: row.name, amountCents: row.amount_cents,
                allocationBasis: row.allocation_basis, notes: row.notes }
            end,
            pricing: {
              unitsPerMonth: project.units_per_month, batchSize: project.batch_size,
              riskSurchargePct: project.risk_surcharge_pct&.to_f,
              autoRiskSurcharge: project.auto_risk_surcharge
            }
          }
        end

        def apply!(project:, document:)
          document = document.deep_symbolize_keys
          counts = Hash.new(0)
          Project.transaction do
            project.materials.destroy_all
            Array(document[:materials]).each do |entry|
              create_material(project, entry)
              counts[:materials] += 1
            end
          end
          counts
        end

        private

        def material_entry(material)
          profile = material.material_risk_profile
          {
            id: material.id, name: material.name, materialType: material.material_type,
            supplier: material.supplier&.name, articleNumber: material.article_number,
            description: material.description, unit: material.unit,
            unitPriceCents: material.unit_price_cents,
            priceIncludesTax: material.price_includes_tax,
            quantity: material.quantity.to_f,
            leadTime: { value: material.lead_time_value.to_f, unit: material.lead_time_unit },
            storageLocation: material.storage_location,
            supplyChainRisk: {
              originCountry: profile&.origin_country,
              shippingRoute: profile&.shipping_route,
              hsCode: profile&.hs_code,
              riskScore: material.risk_score, riskLevel: material.risk_level,
              lastCheckedAt: material.last_risk_checked_at&.iso8601,
              dataSources: Array(material.latest_risk_assessment&.data_sources),
              sanctionsStatus: material.supplier&.sanctions_status,
              manuallyAssessed: profile&.manually_assessed? || false
            }
          }
        end

        def supplier_entry(supplier)
          { name: supplier.name, country: supplier.country, city: supplier.city,
            rating: supplier.rating, isSingleSource: supplier.is_single_source,
            sanctionsStatus: supplier.sanctions_status }
        end

        def create_material(project, entry)
          risk = entry[:supplyChainRisk] || {}
          material = project.materials.create!(
            name: entry[:name], material_type: entry[:materialType] || 'component',
            article_number: entry[:articleNumber], description: entry[:description],
            unit: entry[:unit] || 'Stk', unit_price_cents: entry[:unitPriceCents].to_i,
            quantity: entry[:quantity] || 1,
            lead_time_value: entry.dig(:leadTime, :value) || 0,
            lead_time_unit: entry.dig(:leadTime, :unit) || 'days',
            storage_location: entry[:storageLocation]
          )
          if risk.present?
            material.create_material_risk_profile!(
              origin_country: risk[:originCountry], shipping_route: risk[:shippingRoute],
              hs_code: risk[:hsCode]
            )
          end
          material
        end
      end
    end
  end
end
