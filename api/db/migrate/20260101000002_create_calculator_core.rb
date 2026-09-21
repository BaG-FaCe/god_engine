# `calculator` bounded context - projects, suppliers and materials.
class CreateCalculatorCore < ActiveRecord::Migration[8.0]
  def change
    # --- projects ---------------------------------------------------------
    create_table :projects, id: :string, limit: 36 do |t|
      t.string :name, null: false
      t.text :description
      t.string :status, null: false, default: 'active'

      # Taxation (Tab 4)
      t.decimal :tax_rate, precision: 8, scale: 6, null: false, default: 0.19
      t.string :tax_profile, null: false, default: 'standard'
      t.string :country, null: false, default: 'DE'
      t.string :currency, null: false, default: 'EUR'

      # Volume assumptions
      t.integer :units_per_month, null: false, default: 100
      t.integer :batch_size, null: false, default: 100
      t.decimal :target_margin_pct, precision: 8, scale: 6, null: false, default: 0.25

      # Supply chain risk surcharge (deliverable 8)
      t.decimal :risk_surcharge_pct, precision: 8, scale: 6
      t.boolean :auto_risk_surcharge, null: false, default: true
      t.integer :risk_refresh_interval_hours, null: false, default: 24

      t.string :owner_id
      t.integer :lock_version, null: false, default: 0
      t.datetime :archived_at
      t.timestamps
    end
    add_index :projects, :status
    add_index :projects, :owner_id
    add_index :projects, :name

    # --- suppliers --------------------------------------------------------
    create_table :suppliers, id: :string, limit: 36 do |t|
      t.string :project_id, null: false
      t.string :name, null: false
      t.string :country
      t.string :city
      t.string :contact_name
      t.string :contact_email
      t.string :contact_phone
      t.string :website
      t.integer :rating
      t.boolean :is_single_source, null: false, default: false

      # Compliance (populated by the sanctions provider adapters)
      t.string :sanctions_status, null: false, default: 'unknown'
      t.datetime :sanctions_checked_at
      t.json :sanctions_details

      t.text :notes
      t.timestamps
    end
    add_index :suppliers, :project_id
    add_index :suppliers, :name
    add_index :suppliers, :country
    add_index :suppliers, :sanctions_status
    add_foreign_key :suppliers, :projects, column: :project_id

    # --- materials --------------------------------------------------------
    create_table :materials, id: :string, limit: 36 do |t|
      t.string :project_id, null: false
      t.string :supplier_id
      t.string :name, null: false
      t.string :material_type, null: false, default: 'component'
      t.string :article_number
      t.text :description
      t.string :image_url

      t.string :unit, null: false, default: 'Stk'

      # Purchasing
      t.integer :unit_price_cents, null: false, default: 0
      t.boolean :price_includes_tax, null: false, default: false
      t.decimal :quantity, precision: 14, scale: 4, null: false, default: 1.0
      t.decimal :min_order_quantity, precision: 14, scale: 4, null: false, default: 1.0
      t.string :currency, null: false, default: 'EUR'

      # Logistics (Tab 1)
      t.decimal :lead_time_value, precision: 10, scale: 2, null: false, default: 0.0
      t.string :lead_time_unit, null: false, default: 'days'
      t.integer :lead_time_days, null: false, default: 0
      t.string :storage_location
      t.text :delivery_address

      # Stock
      t.decimal :stock_quantity, precision: 14, scale: 4, null: false, default: 0.0
      t.decimal :reorder_level, precision: 14, scale: 4, null: false, default: 0.0

      t.integer :position, null: false, default: 0

      # Denormalised aggregate of the newest risk assessment, kept in sync by
      # SupplyChainRisk::Application::AggregateProductRisk so list views never
      # need to join the risk tables.
      t.integer :risk_score
      t.string :risk_level
      t.datetime :last_risk_checked_at

      t.timestamps
    end
    add_index :materials, :project_id
    add_index :materials, :supplier_id
    add_index :materials, :name
    add_index :materials, :material_type
    add_index :materials, :risk_level
    add_index :materials, :risk_score
    add_index :materials, %i[project_id position]
    add_foreign_key :materials, :projects, column: :project_id
    add_foreign_key :materials, :suppliers, column: :supplier_id

    # --- alternative suppliers (risk mitigation) --------------------------
    create_table :alternative_suppliers, id: :string, limit: 36 do |t|
      t.string :material_id, null: false
      t.string :supplier_id
      t.string :name, null: false
      t.string :country
      t.integer :priority, null: false, default: 1
      t.integer :lead_time_days
      t.integer :unit_price_cents
      t.text :notes
      t.timestamps
    end
    add_index :alternative_suppliers, :material_id
    add_index :alternative_suppliers, %i[material_id priority]
    add_foreign_key :alternative_suppliers, :materials, column: :material_id

    # --- documents --------------------------------------------------------
    create_table :material_documents, id: :string, limit: 36 do |t|
      t.string :material_id, null: false
      t.string :kind, null: false, default: 'other'
      t.string :name, null: false
      t.string :url, null: false
      t.integer :byte_size
      t.string :content_type
      t.timestamps
    end
    add_index :material_documents, :material_id
    add_foreign_key :material_documents, :materials, column: :material_id
  end
end