# Remaining `supply-chain-risk` tables: provider configuration, daily history,
# cached sanctions lists and provider run bookkeeping.
class CreateSupplyChainRiskOperations < ActiveRecord::Migration[8.0]
  def change
    # --- provider configuration (per project, API keys encrypted at rest) --
    create_table :risk_provider_configs, id: :string, limit: 36 do |t|
      t.string :project_id
      t.string :provider_key, null: false
      t.boolean :enabled, null: false, default: true
      t.integer :poll_interval_minutes, null: false, default: 360
      t.integer :priority, null: false, default: 100
      # ActiveRecord::Encryption ciphertext of the provider API key.
      # The plaintext is never serialised to a client.
      t.text :api_key
      t.json :config
      t.datetime :last_run_at
      t.string :last_run_status
      t.text :last_error
      t.integer :consecutive_failures, null: false, default: 0
      t.timestamps
    end
    add_index :risk_provider_configs, %i[project_id provider_key], unique: true
    add_index :risk_provider_configs, :provider_key
    add_index :risk_provider_configs, :enabled

    # --- daily risk history (powers the timeline chart) --------------------
    create_table :risk_score_snapshots, id: :string, limit: 36 do |t|
      t.string :material_id, null: false
      t.date :captured_on, null: false
      t.integer :risk_score, null: false, default: 0
      t.string :risk_level, null: false, default: 'low'
      t.integer :event_count, null: false, default: 0
      t.timestamps
    end
    add_index :risk_score_snapshots, %i[material_id captured_on], unique: true
    add_index :risk_score_snapshots, :captured_on
    add_foreign_key :risk_score_snapshots, :materials, column: :material_id

    # --- locally cached sanctions / restricted party lists -----------------
    create_table :sanctions_entries, id: :string, limit: 36 do |t|
      t.string :source, null: false
      t.string :list_name, null: false
      t.string :entity_name, null: false
      # Name without legal suffixes, punctuation or accents - used for matching.
      t.string :normalised_name, null: false
      t.string :entity_type, null: false, default: 'entity'
      t.string :country_code
      t.string :program
      t.date :listed_on
      t.json :aliases
      t.json :identifiers
      t.timestamps
    end
    add_index :sanctions_entries, :normalised_name
    add_index :sanctions_entries, :source
    add_index :sanctions_entries, :country_code
    add_index :sanctions_entries, %i[source entity_name], unique: true

    # --- provider run bookkeeping ------------------------------------------
    # Response bodies themselves live in Solid Cache so the primary database
    # stays small; this table tracks freshness and quota consumption.
    create_table :risk_provider_runs, id: :string, limit: 36 do |t|
      t.string :provider_key, null: false
      t.string :project_id
      t.string :status, null: false, default: 'ok'
      t.integer :duration_ms
      t.integer :requests_made, null: false, default: 0
      t.integer :assessments_written, null: false, default: 0
      t.integer :events_written, null: false, default: 0
      t.string :error_class
      t.text :error_message
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.timestamps
    end
    add_index :risk_provider_runs, %i[provider_key started_at]
    add_index :risk_provider_runs, :status
    add_index :risk_provider_runs, :project_id
  end
end