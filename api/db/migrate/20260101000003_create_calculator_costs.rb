# `calculator` bounded context - cost, volume and pricing tables.
class CreateCalculatorCosts < ActiveRecord::Migration[8.0]
  def change
    # --- Tab 2: monthly costs --------------------------------------------
    create_table :monthly_costs, id: :string, limit: 36 do |t|
      t.string :project_id, null: false
      t.string :category, null: false, default: 'other'
      t.string :name, null: false
      t.integer :amount_cents, null: false, default: 0
      t.string :currency, null: false, default: 'EUR'
      t.boolean :is_recurring, null: false, default: true
      t.text :notes
      t.integer :position, null: false, default: 0

      # Benchmark against the historical average, maintained by the template
      # import (deliverable: "Monatskosten mit Vorlagen")
      t.integer :benchmark_amount_cents
      t.timestamps
    end
    add_index :monthly_costs, :project_id
    add_index :monthly_costs, :category
    add_index :monthly_costs, %i[project_id position]
    add_foreign_key :monthly_costs, :projects, column: :project_id

    # --- Tab 2: sales forecast vs. actual --------------------------------
    create_table :sales_forecasts, id: :string, limit: 36 do |t|
      t.string :project_id, null: false
      t.string :period, null: false # YYYY-MM
      t.integer :forecast_units, null: false, default: 0
      t.integer :actual_units
      t.text :notes
      t.timestamps
    end
    add_index :sales_forecasts, %i[project_id period], unique: true
    add_foreign_key :sales_forecasts, :projects, column: :project_id

    # --- Tab 3: labour ----------------------------------------------------
    create_table :labor_costs, id: :string, limit: 36 do |t|
      t.string :project_id, null: false
      t.string :employee, null: false
      t.string :role
      t.string :department
      t.decimal :hours, precision: 12, scale: 2, null: false, default: 0.0
      t.integer :hourly_rate_cents, null: false, default: 0
      t.text :notes
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :labor_costs, :project_id
    add_foreign_key :labor_costs, :projects, column: :project_id

    # --- Tab 3: fixed costs ----------------------------------------------
    create_table :fixed_costs, id: :string, limit: 36 do |t|
      t.string :project_id, null: false
      t.string :category, null: false, default: 'other'
      t.string :name, null: false
      t.integer :amount_cents, null: false, default: 0
      t.string :allocation_basis, null: false, default: 'per_unit'
      t.text :notes
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :fixed_costs, :project_id
    add_index :fixed_costs, :category
    add_foreign_key :fixed_costs, :projects, column: :project_id

    # --- Tab 3: overhead / surcharge rules -------------------------------
    create_table :overhead_rules, id: :string, limit: 36 do |t|
      t.string :project_id, null: false
      t.string :key, null: false
      t.string :name, null: false
      t.decimal :percentage, precision: 8, scale: 6, null: false, default: 0.0
      t.string :base, null: false, default: 'direct_cost'
      # When true the percentage is proposed from the aggregated risk score.
      t.boolean :auto_from_risk, null: false, default: false
      t.boolean :enabled, null: false, default: true
      t.integer :position, null: false, default: 0
      t.text :notes
      t.timestamps
    end
    add_index :overhead_rules, %i[project_id key], unique: true
    add_index :overhead_rules, :base
    add_foreign_key :overhead_rules, :projects, column: :project_id

    # --- Reusable cost templates (save / load / import / export) ---------
    create_table :cost_templates, id: :string, limit: 36 do |t|
      t.string :project_id
      t.string :name, null: false
      t.string :kind, null: false, default: 'mixed'
      t.text :description
      t.boolean :is_global, null: false, default: false
      t.json :items
      t.string :created_by_id
      t.timestamps
    end
    add_index :cost_templates, :project_id
    add_index :cost_templates, :kind
    add_index :cost_templates, :is_global
    add_foreign_key :cost_templates, :projects, column: :project_id

    # --- Tab 4: pricing scenarios ----------------------------------------
    create_table :pricing_scenarios, id: :string, limit: 36 do |t|
      t.string :project_id, null: false
      t.string :name, null: false
      t.integer :target_price_cents
      t.boolean :target_price_includes_tax, null: false, default: true
      t.integer :units_per_month, null: false, default: 0
      t.integer :batch_size, null: false, default: 0
      t.boolean :is_active, null: false, default: false
      t.json :result_snapshot
      t.text :notes
      t.timestamps
    end
    add_index :pricing_scenarios, :project_id
    add_index :pricing_scenarios, %i[project_id name], unique: true
    add_foreign_key :pricing_scenarios, :projects, column: :project_id
  end
end