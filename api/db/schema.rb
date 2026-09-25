# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_01_01_000007) do
  create_table "alternative_suppliers", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.string "country"
    t.datetime "created_at", null: false
    t.integer "lead_time_days"
    t.string "material_id", null: false
    t.string "name", null: false
    t.text "notes"
    t.integer "priority", default: 1, null: false
    t.string "supplier_id"
    t.integer "unit_price_cents"
    t.datetime "updated_at", null: false
    t.index ["material_id", "priority"], name: "index_alternative_suppliers_on_material_id_and_priority"
    t.index ["material_id"], name: "index_alternative_suppliers_on_material_id"
  end

  create_table "audit_logs", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.string "action", null: false
    t.string "auditable_id"
    t.string "auditable_type"
    t.json "changeset"
    t.datetime "created_at", null: false
    t.string "ip"
    t.datetime "occurred_at", null: false
    t.string "project_id"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.string "user_id"
    t.string "user_name"
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
    t.index ["occurred_at"], name: "index_audit_logs_on_occurred_at"
    t.index ["project_id"], name: "index_audit_logs_on_project_id"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "cost_templates", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "created_by_id"
    t.text "description"
    t.boolean "is_global", default: false, null: false
    t.json "items"
    t.string "kind", default: "mixed", null: false
    t.string "name", null: false
    t.string "project_id"
    t.datetime "updated_at", null: false
    t.index ["is_global"], name: "index_cost_templates_on_is_global"
    t.index ["kind"], name: "index_cost_templates_on_kind"
    t.index ["project_id"], name: "index_cost_templates_on_project_id"
  end

  create_table "fixed_costs", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.string "allocation_basis", default: "per_unit", null: false
    t.integer "amount_cents", default: 0, null: false
    t.string "category", default: "other", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "notes"
    t.integer "position", default: 0, null: false
    t.string "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_fixed_costs_on_category"
    t.index ["project_id"], name: "index_fixed_costs_on_project_id"
  end

  create_table "labor_costs", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "department"
    t.string "employee", null: false
    t.integer "hourly_rate_cents", default: 0, null: false
    t.decimal "hours", precision: 12, scale: 2, default: "0.0", null: false
    t.text "notes"
    t.integer "position", default: 0, null: false
    t.string "project_id", null: false
    t.string "role"
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_labor_costs_on_project_id"
  end

  create_table "material_documents", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.integer "byte_size"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "kind", default: "other", null: false
    t.string "material_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["material_id"], name: "index_material_documents_on_material_id"
  end

  create_table "material_risk_profiles", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "freight_cost_trend", default: "unknown", null: false
    t.integer "historical_delay_count"
    t.integer "historical_delay_days"
    t.string "hs_code"
    t.boolean "is_single_source", default: false, null: false
    t.datetime "last_disruption_at"
    t.string "last_disruption_cause"
    t.text "last_disruption_note"
    t.string "manual_risk_level"
    t.text "manual_risk_note"
    t.integer "manual_score_override"
    t.datetime "manually_assessed_at"
    t.string "manually_assessed_by_id"
    t.string "material_id", null: false
    t.string "origin_country"
    t.string "shipping_route"
    t.string "transport_mode"
    t.datetime "updated_at", null: false
    t.index ["material_id"], name: "index_material_risk_profiles_on_material_id", unique: true
    t.index ["origin_country"], name: "index_material_risk_profiles_on_origin_country"
  end

  create_table "materials", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.string "article_number"
    t.datetime "created_at", null: false
    t.string "currency", default: "EUR", null: false
    t.text "delivery_address"
    t.text "description"
    t.string "image_url"
    t.datetime "last_risk_checked_at"
    t.integer "lead_time_days", default: 0, null: false
    t.string "lead_time_unit", default: "days", null: false
    t.decimal "lead_time_value", precision: 10, scale: 2, default: "0.0", null: false
    t.string "material_type", default: "component", null: false
    t.decimal "min_order_quantity", precision: 14, scale: 4, default: "1.0", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.boolean "price_includes_tax", default: false, null: false
    t.string "project_id", null: false
    t.decimal "quantity", precision: 14, scale: 4, default: "1.0", null: false
    t.decimal "reorder_level", precision: 14, scale: 4, default: "0.0", null: false
    t.string "risk_level"
    t.integer "risk_score"
    t.decimal "stock_quantity", precision: 14, scale: 4, default: "0.0", null: false
    t.string "storage_location"
    t.string "supplier_id"
    t.string "unit", default: "Stk", null: false
    t.integer "unit_price_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["material_type"], name: "index_materials_on_material_type"
    t.index ["name"], name: "index_materials_on_name"
    t.index ["project_id", "position"], name: "index_materials_on_project_id_and_position"
    t.index ["project_id"], name: "index_materials_on_project_id"
    t.index ["risk_level"], name: "index_materials_on_risk_level"
    t.index ["risk_score"], name: "index_materials_on_risk_score"
    t.index ["supplier_id"], name: "index_materials_on_supplier_id"
  end

  create_table "monthly_costs", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.integer "amount_cents", default: 0, null: false
    t.integer "benchmark_amount_cents"
    t.string "category", default: "other", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "EUR", null: false
    t.boolean "is_recurring", default: true, null: false
    t.string "name", null: false
    t.text "notes"
    t.integer "position", default: 0, null: false
    t.string "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_monthly_costs_on_category"
    t.index ["project_id", "position"], name: "index_monthly_costs_on_project_id_and_position"
    t.index ["project_id"], name: "index_monthly_costs_on_project_id"
  end

  create_table "overhead_rules", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.boolean "auto_from_risk", default: false, null: false
    t.string "base", default: "direct_cost", null: false
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.string "key", null: false
    t.string "name", null: false
    t.text "notes"
    t.decimal "percentage", precision: 8, scale: 6, default: "0.0", null: false
    t.integer "position", default: 0, null: false
    t.string "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["base"], name: "index_overhead_rules_on_base"
    t.index ["project_id", "key"], name: "index_overhead_rules_on_project_id_and_key", unique: true
  end

  create_table "pricing_scenarios", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.integer "batch_size", default: 0, null: false
    t.datetime "created_at", null: false
    t.boolean "is_active", default: false, null: false
    t.string "name", null: false
    t.text "notes"
    t.string "project_id", null: false
    t.json "result_snapshot"
    t.integer "target_price_cents"
    t.boolean "target_price_includes_tax", default: true, null: false
    t.integer "units_per_month", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "name"], name: "index_pricing_scenarios_on_project_id_and_name", unique: true
    t.index ["project_id"], name: "index_pricing_scenarios_on_project_id"
  end

  create_table "projects", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.datetime "archived_at"
    t.boolean "auto_risk_surcharge", default: true, null: false
    t.integer "batch_size", default: 100, null: false
    t.string "country", default: "DE", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "EUR", null: false
    t.text "description"
    t.integer "lock_version", default: 0, null: false
    t.string "name", null: false
    t.string "owner_id"
    t.integer "risk_refresh_interval_hours", default: 24, null: false
    t.decimal "risk_surcharge_pct", precision: 8, scale: 6
    t.string "status", default: "active", null: false
    t.decimal "target_margin_pct", precision: 8, scale: 6, default: "0.25", null: false
    t.string "tax_profile", default: "standard", null: false
    t.decimal "tax_rate", precision: 8, scale: 6, default: "0.19", null: false
    t.integer "units_per_month", default: 100, null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_projects_on_name"
    t.index ["owner_id"], name: "index_projects_on_owner_id"
    t.index ["status"], name: "index_projects_on_status"
  end

  create_table "risk_assessments", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.decimal "confidence", precision: 5, scale: 4
    t.datetime "created_at", null: false
    t.json "data_sources"
    t.json "dimensions"
    t.datetime "expires_at"
    t.datetime "fetched_at", null: false
    t.integer "lead_time_variance_days"
    t.string "material_id", null: false
    t.string "origin", default: "automatic", null: false
    t.string "provider_key", null: false
    t.string "provider_name", null: false
    t.string "provider_tier", default: "free", null: false
    t.json "raw_payload"
    t.text "reason"
    t.string "risk_level", default: "low", null: false
    t.integer "risk_score", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_risk_assessments_on_expires_at"
    t.index ["material_id", "fetched_at"], name: "index_risk_assessments_on_material_id_and_fetched_at"
    t.index ["material_id", "provider_key", "fetched_at"], name: "idx_on_material_id_provider_key_fetched_at_edd37c610e"
    t.index ["provider_key"], name: "index_risk_assessments_on_provider_key"
    t.index ["risk_level"], name: "index_risk_assessments_on_risk_level"
  end

  create_table "risk_events", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.datetime "acknowledged_at"
    t.string "acknowledged_by_id"
    t.string "country_code"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "event_type", default: "manual", null: false
    t.string "material_id"
    t.json "metadata"
    t.datetime "occurred_at", null: false
    t.string "project_id"
    t.string "severity", default: "medium", null: false
    t.string "source", default: "manual", null: false
    t.string "source_event_id"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["event_type"], name: "index_risk_events_on_event_type"
    t.index ["material_id", "occurred_at"], name: "index_risk_events_on_material_id_and_occurred_at"
    t.index ["occurred_at"], name: "index_risk_events_on_occurred_at"
    t.index ["project_id", "occurred_at"], name: "index_risk_events_on_project_id_and_occurred_at"
    t.index ["severity"], name: "index_risk_events_on_severity"
    t.index ["source", "source_event_id"], name: "index_risk_events_on_source_and_source_event_id", unique: true
  end

  create_table "risk_notifications", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.datetime "acknowledged_at"
    t.string "acknowledged_by_id"
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "dismissed_at"
    t.string "dismissed_by_id"
    t.string "kind", default: "risk_event", null: false
    t.string "material_id"
    t.json "payload"
    t.string "project_id"
    t.datetime "read_at"
    t.string "read_by_id"
    t.string "risk_event_id"
    t.string "severity", default: "medium", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["acknowledged_at"], name: "index_risk_notifications_on_acknowledged_at"
    t.index ["dismissed_at"], name: "index_risk_notifications_on_dismissed_at"
    t.index ["project_id", "created_at"], name: "index_risk_notifications_on_project_id_and_created_at"
    t.index ["read_at"], name: "index_risk_notifications_on_read_at"
    t.index ["severity"], name: "index_risk_notifications_on_severity"
  end

  create_table "risk_provider_configs", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.text "api_key"
    t.json "config"
    t.integer "consecutive_failures", default: 0, null: false
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.text "last_error"
    t.datetime "last_run_at"
    t.string "last_run_status"
    t.integer "poll_interval_minutes", default: 360, null: false
    t.integer "priority", default: 100, null: false
    t.string "project_id"
    t.string "provider_key", null: false
    t.datetime "updated_at", null: false
    t.index ["enabled"], name: "index_risk_provider_configs_on_enabled"
    t.index ["project_id", "provider_key"], name: "index_risk_provider_configs_on_project_id_and_provider_key", unique: true
    t.index ["provider_key"], name: "index_risk_provider_configs_on_provider_key"
  end

  create_table "risk_provider_runs", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.integer "assessments_written", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.string "error_class"
    t.text "error_message"
    t.integer "events_written", default: 0, null: false
    t.datetime "finished_at"
    t.string "project_id"
    t.string "provider_key", null: false
    t.integer "requests_made", default: 0, null: false
    t.datetime "started_at", null: false
    t.string "status", default: "ok", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_risk_provider_runs_on_project_id"
    t.index ["provider_key", "started_at"], name: "index_risk_provider_runs_on_provider_key_and_started_at"
    t.index ["status"], name: "index_risk_provider_runs_on_status"
  end

  create_table "risk_score_snapshots", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.date "captured_on", null: false
    t.datetime "created_at", null: false
    t.integer "event_count", default: 0, null: false
    t.string "material_id", null: false
    t.string "risk_level", default: "low", null: false
    t.integer "risk_score", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["captured_on"], name: "index_risk_score_snapshots_on_captured_on"
    t.index ["material_id", "captured_on"], name: "index_risk_score_snapshots_on_material_id_and_captured_on", unique: true
  end

  create_table "sales_forecasts", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.integer "actual_units"
    t.datetime "created_at", null: false
    t.integer "forecast_units", default: 0, null: false
    t.text "notes"
    t.string "period", null: false
    t.string "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "period"], name: "index_sales_forecasts_on_project_id_and_period", unique: true
  end

  create_table "sanctions_entries", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.json "aliases"
    t.string "country_code"
    t.datetime "created_at", null: false
    t.string "entity_name", null: false
    t.string "entity_type", default: "entity", null: false
    t.json "identifiers"
    t.string "list_name", null: false
    t.date "listed_on"
    t.string "normalised_name", null: false
    t.string "program"
    t.string "source", null: false
    t.datetime "updated_at", null: false
    t.index ["country_code"], name: "index_sanctions_entries_on_country_code"
    t.index ["normalised_name"], name: "index_sanctions_entries_on_normalised_name"
    t.index ["source", "entity_name"], name: "index_sanctions_entries_on_source_and_entity_name", unique: true
    t.index ["source"], name: "index_sanctions_entries_on_source"
  end

  create_table "suppliers", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.string "city"
    t.string "contact_email"
    t.string "contact_name"
    t.string "contact_phone"
    t.string "country"
    t.datetime "created_at", null: false
    t.boolean "is_single_source", default: false, null: false
    t.string "name", null: false
    t.text "notes"
    t.string "project_id", null: false
    t.integer "rating"
    t.datetime "sanctions_checked_at"
    t.json "sanctions_details"
    t.string "sanctions_status", default: "unknown", null: false
    t.datetime "updated_at", null: false
    t.string "website"
    t.index ["country"], name: "index_suppliers_on_country"
    t.index ["name"], name: "index_suppliers_on_name"
    t.index ["project_id"], name: "index_suppliers_on_project_id"
    t.index ["sanctions_status"], name: "index_suppliers_on_sanctions_status"
  end

  create_table "users", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "last_login_at"
    t.string "locale", default: "de", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.string "role", default: "manager", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_users_on_active"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "alternative_suppliers", "materials"
  add_foreign_key "cost_templates", "projects"
  add_foreign_key "fixed_costs", "projects"
  add_foreign_key "labor_costs", "projects"
  add_foreign_key "material_documents", "materials"
  add_foreign_key "material_risk_profiles", "materials"
  add_foreign_key "materials", "projects"
  add_foreign_key "materials", "suppliers"
  add_foreign_key "monthly_costs", "projects"
  add_foreign_key "overhead_rules", "projects"
  add_foreign_key "pricing_scenarios", "projects"
  add_foreign_key "risk_assessments", "materials"
  add_foreign_key "risk_events", "materials"
  add_foreign_key "risk_events", "projects"
  add_foreign_key "risk_notifications", "materials"
  add_foreign_key "risk_notifications", "projects"
  add_foreign_key "risk_score_snapshots", "materials"
  add_foreign_key "sales_forecasts", "projects"
  add_foreign_key "suppliers", "projects"
end
