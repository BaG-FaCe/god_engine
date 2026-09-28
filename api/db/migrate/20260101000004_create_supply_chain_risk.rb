# `supply-chain-risk` bounded context.
#
# Database placement (see DatabaseSetup::TableRouting):
#   material_risk_profiles, risk_assessments -> `productdata`
#   risk_events (+ risk_event_metadata)      -> `events`
#
# Every table in this migration belongs to the risk module. The `calculator`
# context only ever reads material risk through the module's public API or the
# denormalised `materials.risk_score` column - never through these tables
# directly (enforced by spec/architecture/module_boundaries_spec.rb).
class CreateSupplyChainRisk < DatabaseSetup::PlatformMigration
  def change
    # --- manually maintained risk master data per material ---------------
    routed_create_table :material_risk_profiles, id: :string, limit: 36 do |t|
      t.string :material_id, null: false
      t.string :origin_country
      t.string :hs_code
      t.string :shipping_route
      t.string :transport_mode
      t.boolean :is_single_source, null: false, default: false

      # Historical performance feeds the internal heuristic provider
      t.integer :historical_delay_count
      t.integer :historical_delay_days
      t.datetime :last_disruption_at
      t.string :last_disruption_cause
      t.text :last_disruption_note
      t.string :freight_cost_trend, null: false, default: 'unknown'

      # Manual traffic light - the fallback when no provider is configured
      t.string :manual_risk_level
      t.text :manual_risk_note
      t.integer :manual_score_override
      t.datetime :manually_assessed_at
      t.string :manually_assessed_by_id
      t.timestamps
    end
    routed_add_index :material_risk_profiles, :material_id, unique: true
    routed_add_index :material_risk_profiles, :origin_country
    routed_add_foreign_key :material_risk_profiles, :materials, column: :material_id

    # --- provider results -------------------------------------------------
    routed_create_table :risk_assessments, id: :string, limit: 36 do |t|
      t.string :material_id, null: false
      t.string :provider_key, null: false
      t.string :provider_name, null: false
      t.string :provider_tier, null: false, default: 'free'
      t.integer :risk_score, null: false, default: 0
      t.string :risk_level, null: false, default: 'low'
      t.json :dimensions
      t.integer :lead_time_variance_days
      t.text :reason
      t.string :origin, null: false, default: 'automatic'
      t.datetime :fetched_at, null: false
      t.datetime :expires_at
      t.json :data_sources
      t.json :raw_payload
      t.decimal :confidence, precision: 5, scale: 4
      t.timestamps
    end
    routed_add_index :risk_assessments, %i[material_id fetched_at]
    routed_add_index :risk_assessments, %i[material_id provider_key fetched_at]
    routed_add_index :risk_assessments, :provider_key
    routed_add_index :risk_assessments, :risk_level
    routed_add_index :risk_assessments, :expires_at
    routed_add_foreign_key :risk_assessments, :materials, column: :material_id

    # --- risk events / early warning feed (events database) ---------------
    routed_create_table :risk_events, id: :string, limit: 36 do |t|
      t.string :material_id
      t.string :project_id
      t.string :country_code
      t.string :event_type, null: false, default: 'manual'
      t.string :severity, null: false, default: 'medium'
      t.string :title, null: false
      t.text :description
      t.string :source, null: false, default: 'manual'
      t.string :source_event_id
      t.datetime :occurred_at, null: false
      t.datetime :acknowledged_at
      t.string :acknowledged_by_id
      t.json :metadata
      t.timestamps
    end
    routed_add_index :risk_events, %i[source source_event_id], unique: true
    routed_add_index :risk_events, %i[material_id occurred_at]
    routed_add_index :risk_events, %i[project_id occurred_at]
    routed_add_index :risk_events, :severity
    routed_add_index :risk_events, :event_type
    routed_add_index :risk_events, :occurred_at
    # `risk_events` lives in a separate database, so the references to materials
    # and projects are logical (application-enforced), not database-level keys.
    routed_add_foreign_key :risk_events, :materials, column: :material_id
    routed_add_foreign_key :risk_events, :projects, column: :project_id
  end
end
