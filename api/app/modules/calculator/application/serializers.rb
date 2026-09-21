module Calculator
  module Application
    # Serializers for the calculator context (camelCase REST contract).
    module Serializers
      class << self
        def project(project)
          {
            id: project.id, name: project.name, description: project.description,
            status: project.status, taxRate: project.tax_rate.to_f,
            taxProfile: project.tax_profile, country: project.country,
            currency: project.currency, unitsPerMonth: project.units_per_month,
            batchSize: project.batch_size, targetMarginPct: project.target_margin_pct.to_f,
            riskSurchargePct: project.risk_surcharge_pct&.to_f,
            autoRiskSurcharge: project.auto_risk_surcharge,
            riskRefreshIntervalHours: project.risk_refresh_interval_hours,
            archivedAt: project.archived_at&.iso8601,
            createdAt: project.created_at&.iso8601, updatedAt: project.updated_at&.iso8601
          }
        end

        def supplier(supplier)
          {
            id: supplier.id, projectId: supplier.project_id, name: supplier.name,
            country: supplier.country, city: supplier.city,
            contactName: supplier.contact_name, contactEmail: supplier.contact_email,
            contactPhone: supplier.contact_phone, website: supplier.website,
            rating: supplier.rating, isSingleSource: supplier.is_single_source,
            sanctionsStatus: supplier.sanctions_status,
            sanctionsCheckedAt: supplier.sanctions_checked_at&.iso8601,
            sanctionsDetails: supplier.sanctions_details, notes: supplier.notes,
            createdAt: supplier.created_at&.iso8601, updatedAt: supplier.updated_at&.iso8601
          }
        end

        def alternative_supplier(record)
          {
            id: record.id, materialId: record.material_id, supplierId: record.supplier_id,
            name: record.name, country: record.country, priority: record.priority,
            leadTimeDays: record.lead_time_days, unitPriceCents: record.unit_price_cents,
            notes: record.notes
          }
        end

        def monthly_cost(row)
          {
            id: row.id, projectId: row.project_id, category: row.category, name: row.name,
            amountCents: row.amount_cents, currency: row.currency,
            isRecurring: row.is_recurring, notes: row.notes, position: row.position,
            createdAt: row.created_at&.iso8601, updatedAt: row.updated_at&.iso8601
          }
        end

        def sales_forecast(row)
          {
            id: row.id, projectId: row.project_id, period: row.period,
            forecastUnits: row.forecast_units, actualUnits: row.actual_units, notes: row.notes
          }
        end

        def labor_cost(row)
          {
            id: row.id, projectId: row.project_id, employee: row.employee, role: row.role,
            department: row.department, hours: row.hours.to_f,
            hourlyRateCents: row.hourly_rate_cents, totalCents: row.total_cents,
            notes: row.notes
          }
        end

        def fixed_cost(row)
          {
            id: row.id, projectId: row.project_id, category: row.category, name: row.name,
            amountCents: row.amount_cents, allocationBasis: row.allocation_basis,
            notes: row.notes, perUnitCents: nil
          }
        end

        def overhead_rule(rule, suggested: nil)
          {
            id: rule.id, projectId: rule.project_id, key: rule.key, name: rule.name,
            percentage: rule.percentage.to_f, base: rule.base,
            autoFromRisk: rule.auto_from_risk, enabled: rule.enabled,
            position: rule.position, notes: rule.notes,
            suggestedPercentage: suggested
          }
        end

        def pricing_scenario(scenario)
          {
            id: scenario.id, projectId: scenario.project_id, name: scenario.name,
            targetPriceCents: scenario.target_price_cents,
            targetPriceIncludesTax: scenario.target_price_includes_tax,
            unitsPerMonth: scenario.units_per_month, batchSize: scenario.batch_size,
            isActive: scenario.is_active, resultSnapshot: scenario.result_snapshot,
            notes: scenario.notes,
            createdAt: scenario.created_at&.iso8601, updatedAt: scenario.updated_at&.iso8601
          }
        end

        def cost_template(template)
          {
            id: template.id, projectId: template.project_id, name: template.name,
            kind: template.kind, description: template.description,
            isGlobal: template.is_global, items: Array(template.items),
            itemCount: template.item_count, totalCents: template.total_cents,
            createdAt: template.created_at&.iso8601, updatedAt: template.updated_at&.iso8601
          }
        end
      end
    end
  end
end
