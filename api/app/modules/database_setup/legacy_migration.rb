# frozen_string_literal: true

module DatabaseSetup
  # Migrates legacy data (file based SQLite) into the SQL backend.
  #
  # The snapshot is read through `LegacySource` (raw, read-only SQLite access),
  # while the write goes through the application's *actual* models (not invented
  # table copies) in foreign-key dependency order. Because every model is bound
  # to the record class of its logical database, `insert_all` automatically
  # writes each table into `productdata`, `users`, `events` or `logs`.
  #
  # UUID primary keys and relationships are preserved. The migration is
  # idempotent: records whose primary key already exists on the target are
  # skipped, so re-running it never duplicates or corrupts data.
  #
  # Encrypted columns (e.g. RiskProviderConfig#api_key) are copied as ciphertext,
  # which round-trips correctly as long as source and target use the same
  # ActiveRecord::Encryption keys (they belong to the same application).
  class LegacyMigration
    # Foreign-key dependency order: parents before children.
    TABLES = %w[
      users
      projects
      suppliers
      materials
      material_risk_profiles
      alternative_suppliers
      material_documents
      monthly_costs
      sales_forecasts
      labor_costs
      fixed_costs
      overhead_rules
      cost_templates
      cost_template_items
      pricing_scenarios
      pricing_scenario_results
      pricing_scenario_warnings
      risk_assessments
      risk_assessment_dimensions
      risk_assessment_data_sources
      risk_events
      risk_event_metadata
      risk_notifications
      risk_provider_configs
      risk_score_snapshots
      sanctions_entries
      sanctions_entry_aliases
      sanctions_entry_identifiers
      risk_provider_runs
      audit_logs
      audit_log_changes
      audit_log_metadata
    ].freeze

    MODELS = {
      'users' => ::User,
      'projects' => ::Project,
      'suppliers' => ::Supplier,
      'materials' => ::Material,
      'material_risk_profiles' => ::MaterialRiskProfile,
      'alternative_suppliers' => ::AlternativeSupplier,
      'material_documents' => ::MaterialDocument,
      'monthly_costs' => ::MonthlyCost,
      'sales_forecasts' => ::SalesForecast,
      'labor_costs' => ::LaborCost,
      'fixed_costs' => ::FixedCost,
      'overhead_rules' => ::OverheadRule,
      'cost_templates' => ::CostTemplate,
      'cost_template_items' => ::CostTemplateItem,
      'pricing_scenarios' => ::PricingScenario,
      'pricing_scenario_results' => ::PricingScenarioResult,
      'pricing_scenario_warnings' => ::PricingScenarioWarning,
      'risk_assessments' => ::RiskAssessment,
      'risk_assessment_dimensions' => ::RiskAssessmentDimension,
      'risk_assessment_data_sources' => ::RiskAssessmentDataSource,
      'risk_events' => ::RiskEvent,
      'risk_event_metadata' => ::RiskEventMetadatum,
      'risk_notifications' => ::RiskNotification,
      'risk_provider_configs' => ::RiskProviderConfig,
      'risk_score_snapshots' => ::RiskScoreSnapshot,
      'sanctions_entries' => ::SanctionsEntry,
      'sanctions_entry_aliases' => ::SanctionsEntryAlias,
      'sanctions_entry_identifiers' => ::SanctionsEntryIdentifier,
      'risk_provider_runs' => ::RiskProviderRun,
      'audit_logs' => ::AuditLog,
      'audit_log_changes' => ::AuditLogChange,
      'audit_log_metadata' => ::AuditLogMetadatum
    }.freeze

    class << self
      # Reads every table of the legacy store (the file based SQLite database)
      # into memory: { table => [row hashes] }. Only SELECTs are issued - the
      # legacy file is never modified.
      def extract(source: nil)
        (source || LegacySource.new).extract(TABLES)
      end

      # Writes the extracted snapshot to the current ActiveRecord connection
      # (the SQL Server target, after SchemaLoader switched the connection).
      # Returns { table => inserted_count }.
      def import(snapshot)
        TABLES.each_with_object({}) do |table, result|
          rows = snapshot.fetch(table, [])
          next if rows.empty?

          result[table] = insert_missing(MODELS.fetch(table), rows)
        end
      end
    end

    # Inserts only rows whose primary key is absent on the target (idempotent).
    def self.insert_missing(model, rows)
      ids = rows.map { |row| row['id'] }.compact
      return 0 if ids.empty?

      existing = model.where(id: ids).pluck(:id).to_set
      fresh = rows.reject { |row| existing.include?(row['id']) }
      model.insert_all(fresh) unless fresh.empty?
      fresh.size
    end
    private_class_method :insert_missing
  end
end
