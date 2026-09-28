# frozen_string_literal: true

# Replaces every persistent JSON column with a properly normalised relational
# SQL model (see project_documentation/19_json_to_sql_migration.md).
#
# Normalised:
#   * cost_templates.items            -> cost_template_items
#   * risk_assessments.dimensions     -> risk_assessment_dimensions
#   * risk_assessments.data_sources   -> risk_assessment_data_sources
#   * risk_events.metadata            -> risk_event_metadata
#   * sanctions_entries.aliases       -> sanctions_entry_aliases
#   * sanctions_entries.identifiers   -> sanctions_entry_identifiers
#   * audit_logs.changeset            -> audit_log_changes + audit_log_metadata
#   * pricing_scenarios.result_snapshot (PriceOptimizer::Result)
#                                     -> pricing_scenario_results (1:1) + pricing_scenario_warnings
#   * risk_notifications.payload      -> typed columns on risk_notifications
#
# Remains opaque TEXT (documented special cases - API payload / configuration /
# unstructured screening result):
#   * risk_assessments.raw_payload, risk_provider_configs.config,
#     suppliers.sanctions_details
class NormalizeJsonToRelational < DatabaseSetup::PlatformMigration
  def up
    create_cost_template_items
    create_risk_assessment_dimensions
    create_risk_assessment_data_sources
    create_risk_event_metadata
    create_sanctions_entry_aliases
    create_sanctions_entry_identifiers
    create_audit_log_children
    create_pricing_scenario_results

    add_notification_payload_columns

    backfill_cost_template_items
    backfill_risk_assessment_details
    backfill_risk_event_metadata
    backfill_sanctions_children
    backfill_audit_log_children
    backfill_pricing_scenario_results
    backfill_risk_notification_payload

    drop_json_columns
  end

  def down
    re_add_json_columns
    reverse_backfills
    remove_notification_payload_columns

    routed_drop_table :pricing_scenario_warnings
    routed_drop_table :pricing_scenario_results
    routed_drop_table :audit_log_metadata
    routed_drop_table :audit_log_changes
    routed_drop_table :sanctions_entry_identifiers
    routed_drop_table :sanctions_entry_aliases
    routed_drop_table :risk_event_metadata
    routed_drop_table :risk_assessment_data_sources
    routed_drop_table :risk_assessment_dimensions
    routed_drop_table :cost_template_items
  end

  private

  # --- DDL ---------------------------------------------------------------

  def create_cost_template_items
    routed_create_table :cost_template_items, id: :string, limit: 36 do |t|
      t.string :cost_template_id, null: false
      t.integer :position, null: false, default: 0
      t.string :category, null: false, default: 'other'
      t.string :name, null: false
      t.integer :amount_cents, null: false, default: 0
      t.boolean :is_recurring, null: false, default: true
      t.text :notes
      t.string :employee
      t.string :role
      t.decimal :hours, precision: 12, scale: 2
      t.integer :hourly_rate_cents
      t.string :allocation_basis, null: false, default: 'per_unit'
      t.timestamps
    end
    routed_add_index :cost_template_items, :cost_template_id
    routed_add_index :cost_template_items, %i[cost_template_id position]
    routed_add_foreign_key :cost_template_items, :cost_templates, column: :cost_template_id
  end

  def create_risk_assessment_dimensions
    routed_create_table :risk_assessment_dimensions, id: :string, limit: 36 do |t|
      t.string :risk_assessment_id, null: false
      t.string :dimension_key, null: false
      t.integer :score, null: false, default: 0
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    routed_add_index :risk_assessment_dimensions, %i[risk_assessment_id dimension_key], unique: true
    routed_add_foreign_key :risk_assessment_dimensions, :risk_assessments, column: :risk_assessment_id
  end

  def create_risk_assessment_data_sources
    routed_create_table :risk_assessment_data_sources, id: :string, limit: 36 do |t|
      t.string :risk_assessment_id, null: false
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    routed_add_index :risk_assessment_data_sources, :risk_assessment_id
    routed_add_foreign_key :risk_assessment_data_sources, :risk_assessments, column: :risk_assessment_id
  end

  def create_risk_event_metadata
    routed_create_table :risk_event_metadata, id: :string, limit: 36 do |t|
      t.string :risk_event_id, null: false
      t.string :key, null: false
      t.text :value
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    routed_add_index :risk_event_metadata, :risk_event_id
    routed_add_foreign_key :risk_event_metadata, :risk_events, column: :risk_event_id
  end

  def create_sanctions_entry_aliases
    routed_create_table :sanctions_entry_aliases, id: :string, limit: 36 do |t|
      t.string :sanctions_entry_id, null: false
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    routed_add_index :sanctions_entry_aliases, :sanctions_entry_id
    routed_add_foreign_key :sanctions_entry_aliases, :sanctions_entries, column: :sanctions_entry_id
  end

  def create_sanctions_entry_identifiers
    routed_create_table :sanctions_entry_identifiers, id: :string, limit: 36 do |t|
      t.string :sanctions_entry_id, null: false
      t.string :identifier_type, null: false
      t.string :value
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    routed_add_index :sanctions_entry_identifiers, :sanctions_entry_id
    routed_add_foreign_key :sanctions_entry_identifiers, :sanctions_entries, column: :sanctions_entry_id
  end

  def create_audit_log_children
    routed_create_table :audit_log_changes, id: :string, limit: 36 do |t|
      t.string :audit_log_id, null: false
      t.string :attribute_name, null: false
      t.text :old_value
      t.text :new_value
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    routed_add_index :audit_log_changes, :audit_log_id
    routed_add_foreign_key :audit_log_changes, :audit_logs, column: :audit_log_id

    routed_create_table :audit_log_metadata, id: :string, limit: 36 do |t|
      t.string :audit_log_id, null: false
      t.string :key, null: false
      t.text :value
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    routed_add_index :audit_log_metadata, :audit_log_id
    routed_add_foreign_key :audit_log_metadata, :audit_logs, column: :audit_log_id
  end

  def create_pricing_scenario_results
    routed_create_table :pricing_scenario_results, id: :string, limit: 36 do |t|
      t.string :pricing_scenario_id, null: false
      # target
      t.integer :target_price_cents
      t.boolean :target_includes_tax
      t.integer :target_net_cents
      t.integer :target_gross_cents
      # calculated
      t.integer :calculated_net_cents
      t.integer :calculated_gross_cents
      # profit
      t.integer :profit_per_unit_net_cents
      t.integer :profit_per_unit_gross_cents
      t.decimal :profit_margin_pct, precision: 10, scale: 6
      t.decimal :profit_markup_pct, precision: 10, scale: 6
      t.integer :profit_contribution_margin_per_unit_cents
      t.decimal :profit_contribution_margin_ratio_pct, precision: 10, scale: 6
      t.integer :profit_variable_cost_per_unit_cents
      t.integer :profit_full_cost_per_unit_cents
      # revenue
      t.integer :revenue_monthly_net_cents
      t.integer :revenue_monthly_gross_cents
      t.integer :revenue_batch_net_cents
      t.integer :revenue_batch_gross_cents
      # monthly profit
      t.integer :monthly_profit_net_cents
      t.decimal :monthly_profit_margin_pct, precision: 10, scale: 6
      t.integer :monthly_profit_units_per_month
      # break even
      t.integer :break_even_units_per_month
      t.integer :break_even_revenue_net_cents
      t.boolean :break_even_feasible
      t.text :break_even_reason
      t.decimal :break_even_coverage_ratio_pct, precision: 10, scale: 6
      t.integer :break_even_current_volume
      # variable cost
      t.integer :variable_cost_per_unit_cents
      t.decimal :variable_cost_share_of_price_pct, precision: 10, scale: 6
      # fixed cost
      t.integer :fixed_cost_per_month_cents
      t.integer :fixed_cost_per_unit_at_volume_cents
      t.timestamps
    end
    routed_add_index :pricing_scenario_results, :pricing_scenario_id, unique: true
    routed_add_foreign_key :pricing_scenario_results, :pricing_scenarios, column: :pricing_scenario_id

    routed_create_table :pricing_scenario_warnings, id: :string, limit: 36 do |t|
      t.string :pricing_scenario_result_id, null: false
      t.integer :position, null: false, default: 0
      t.text :message, null: false
      t.timestamps
    end
    routed_add_index :pricing_scenario_warnings, :pricing_scenario_result_id
    routed_add_foreign_key :pricing_scenario_warnings, :pricing_scenario_results, column: :pricing_scenario_result_id
  end

  def add_notification_payload_columns
    routed_add_column :risk_notifications, :source, :string
    routed_add_column :risk_notifications, :country_code, :string
    routed_add_column :risk_notifications, :event_type, :string
    routed_add_column :risk_notifications, :risk_score, :integer
    routed_add_column :risk_notifications, :risk_level, :string
  end

  def drop_json_columns
    routed_remove_column :cost_templates, :items
    routed_remove_column :risk_assessments, :dimensions
    routed_remove_column :risk_assessments, :data_sources
    routed_remove_column :risk_events, :metadata
    routed_remove_column :sanctions_entries, :aliases
    routed_remove_column :sanctions_entries, :identifiers
    routed_remove_column :audit_logs, :changeset
    routed_remove_column :pricing_scenarios, :result_snapshot
    routed_remove_column :risk_notifications, :payload

    routed_change_column :risk_assessments, :raw_payload, :text
    routed_change_column :risk_provider_configs, :config, :text
    routed_change_column :suppliers, :sanctions_details, :text
  end

  def re_add_json_columns
    routed_change_column :suppliers, :sanctions_details, :json
    routed_change_column :risk_provider_configs, :config, :json
    routed_change_column :risk_assessments, :raw_payload, :json

    routed_add_column :risk_notifications, :payload, :json
    routed_add_column :pricing_scenarios, :result_snapshot, :json
    routed_add_column :audit_logs, :changeset, :json
    routed_add_column :sanctions_entries, :identifiers, :json
    routed_add_column :sanctions_entries, :aliases, :json
    routed_add_column :risk_events, :metadata, :json
    routed_add_column :risk_assessments, :data_sources, :json
    routed_add_column :risk_assessments, :dimensions, :json
    routed_add_column :cost_templates, :items, :json
  end

  def remove_notification_payload_columns
    routed_remove_column :risk_notifications, :risk_level
    routed_remove_column :risk_notifications, :risk_score
    routed_remove_column :risk_notifications, :event_type
    routed_remove_column :risk_notifications, :country_code
    routed_remove_column :risk_notifications, :source
  end

  # --- Forward backfills (JSON -> relational) -----------------------------

  def backfill_cost_template_items
    rows = []
    routed_select_all(:cost_templates, 'SELECT id, items FROM cost_templates WHERE items IS NOT NULL').each do |row|
      items = parse_json(row['items'])
      next unless items.is_a?(Array)

      items.each_with_index do |raw, index|
        item = raw.respond_to?(:to_h) ? raw.to_h : {}
        item = item.symbolize_keys
        rows << {
          id: SecureRandom.uuid,
          cost_template_id: row['id'],
          position: index,
          category: presence(item[:category], 'other'),
          name: presence(item[:name], 'Position'),
          amount_cents: cents(item[:amount_cents]),
          is_recurring: item.fetch(:is_recurring, true),
          notes: item[:notes],
          employee: item[:employee],
          role: item[:role],
          hours: item[:hours] && BigDecimal(item[:hours].to_s),
          hourly_rate_cents: item[:hourly_rate_cents] && cents(item[:hourly_rate_cents]),
          allocation_basis: presence(item[:allocation_basis], 'per_unit'),
          created_at: Time.current,
          updated_at: Time.current
        }
      end
    end
    insert_rows(:cost_template_items, rows)
  end

  def backfill_risk_assessment_details
    dimension_rows = []
    source_rows = []
    routed_select_all(:risk_assessments, 'SELECT id, dimensions, data_sources FROM risk_assessments').each do |row|
      dimensions = parse_json(row['dimensions'])
      if dimensions.is_a?(Hash)
        dimensions.stringify_keys.each_with_index do |(key, value), index|
          next if value.nil?

          dimension_rows << {
            id: SecureRandom.uuid, risk_assessment_id: row['id'], dimension_key: key,
            score: [[value.to_f.round, 0].max, 100].min, position: index,
            created_at: Time.current, updated_at: Time.current
          }
        end
      end

      Array(parse_json(row['data_sources'])).each_with_index do |name, index|
        next if name.blank?

        source_rows << {
          id: SecureRandom.uuid, risk_assessment_id: row['id'], name: name.to_s,
          position: index, created_at: Time.current, updated_at: Time.current
        }
      end
    end
    insert_rows(:risk_assessment_dimensions, dimension_rows)
    insert_rows(:risk_assessment_data_sources, source_rows)
  end

  def backfill_risk_event_metadata
    rows = []
    routed_select_all(:risk_events, 'SELECT id, metadata FROM risk_events WHERE metadata IS NOT NULL').each do |row|
      metadata = parse_json(row['metadata'])
      next unless metadata.is_a?(Hash)

      metadata.stringify_keys.each_with_index do |(key, value), index|
        rows << {
          id: SecureRandom.uuid, risk_event_id: row['id'], key: key,
          value: value.to_json, position: index,
          created_at: Time.current, updated_at: Time.current
        }
      end
    end
    insert_rows(:risk_event_metadata, rows)
  end

  def backfill_sanctions_children
    alias_rows = []
    identifier_rows = []
    routed_select_all(:sanctions_entries, 'SELECT id, aliases, identifiers FROM sanctions_entries').each do |row|
      Array(parse_json(row['aliases'])).each_with_index do |name, index|
        next if name.blank?

        alias_rows << {
          id: SecureRandom.uuid, sanctions_entry_id: row['id'], name: name.to_s,
          position: index, created_at: Time.current, updated_at: Time.current
        }
      end

      identifiers = parse_json(row['identifiers'])
      if identifiers.is_a?(Hash)
        identifiers.stringify_keys.each_with_index do |(type, value), index|
          next if value.blank?

          identifier_rows << {
            id: SecureRandom.uuid, sanctions_entry_id: row['id'], identifier_type: type,
            value: value.to_s, position: index,
            created_at: Time.current, updated_at: Time.current
          }
        end
      end
    end
    insert_rows(:sanctions_entry_aliases, alias_rows)
    insert_rows(:sanctions_entry_identifiers, identifier_rows)
  end

  def backfill_audit_log_children
    change_rows = []
    metadata_rows = []
    routed_select_all(:audit_logs, 'SELECT id, changeset FROM audit_logs WHERE changeset IS NOT NULL').each do |row|
      changeset = parse_json(row['changeset'])
      next unless changeset.is_a?(Hash)

      changeset.stringify_keys.each_with_index do |(key, value), index|
        if value.is_a?(Hash) && value.key?('from') && value.key?('to')
          change_rows << {
            id: SecureRandom.uuid, audit_log_id: row['id'], attribute_name: key,
            old_value: value['from'].to_json, new_value: value['to'].to_json,
            position: index, created_at: Time.current, updated_at: Time.current
          }
        else
          metadata_rows << {
            id: SecureRandom.uuid, audit_log_id: row['id'], key: key,
            value: value.to_json, position: index,
            created_at: Time.current, updated_at: Time.current
          }
        end
      end
    end
    insert_rows(:audit_log_changes, change_rows)
    insert_rows(:audit_log_metadata, metadata_rows)
  end

  def backfill_pricing_scenario_results
    rows = []
    warning_rows = []
    routed_select_all(:pricing_scenarios, 'SELECT id, result_snapshot FROM pricing_scenarios WHERE result_snapshot IS NOT NULL').each do |row|
      snapshot = parse_json(row['result_snapshot'])
      next unless snapshot.is_a?(Hash)

      snapshot = snapshot.deep_symbolize_keys
      result_id = SecureRandom.uuid
      rows << {
        id: result_id, pricing_scenario_id: row['id'],
        target_price_cents: snapshot.dig(:target, :priceCents),
        target_includes_tax: snapshot.dig(:target, :includesTax),
        target_net_cents: snapshot.dig(:target, :netCents),
        target_gross_cents: snapshot.dig(:target, :grossCents),
        calculated_net_cents: snapshot.dig(:calculated, :netCents),
        calculated_gross_cents: snapshot.dig(:calculated, :grossCents),
        profit_per_unit_net_cents: snapshot.dig(:profit, :perUnitNetCents),
        profit_per_unit_gross_cents: snapshot.dig(:profit, :perUnitGrossCents),
        profit_margin_pct: snapshot.dig(:profit, :marginPct),
        profit_markup_pct: snapshot.dig(:profit, :markupPct),
        profit_contribution_margin_per_unit_cents: snapshot.dig(:profit, :contributionMarginPerUnitCents),
        profit_contribution_margin_ratio_pct: snapshot.dig(:profit, :contributionMarginRatioPct),
        profit_variable_cost_per_unit_cents: snapshot.dig(:profit, :variableCostPerUnitCents),
        profit_full_cost_per_unit_cents: snapshot.dig(:profit, :fullCostPerUnitCents),
        revenue_monthly_net_cents: snapshot.dig(:revenue, :monthlyNetCents),
        revenue_monthly_gross_cents: snapshot.dig(:revenue, :monthlyGrossCents),
        revenue_batch_net_cents: snapshot.dig(:revenue, :batchNetCents),
        revenue_batch_gross_cents: snapshot.dig(:revenue, :batchGrossCents),
        monthly_profit_net_cents: snapshot.dig(:monthlyProfit, :netCents),
        monthly_profit_margin_pct: snapshot.dig(:monthlyProfit, :marginPct),
        monthly_profit_units_per_month: snapshot.dig(:monthlyProfit, :unitsPerMonth),
        break_even_units_per_month: snapshot.dig(:breakEven, :unitsPerMonth),
        break_even_revenue_net_cents: snapshot.dig(:breakEven, :revenueNetCents),
        break_even_feasible: snapshot.dig(:breakEven, :feasible),
        break_even_reason: snapshot.dig(:breakEven, :reason),
        break_even_coverage_ratio_pct: snapshot.dig(:breakEven, :coverageRatioPct),
        break_even_current_volume: snapshot.dig(:breakEven, :currentVolume),
        variable_cost_per_unit_cents: snapshot.dig(:variableCost, :perUnitCents),
        variable_cost_share_of_price_pct: snapshot.dig(:variableCost, :shareOfPricePct),
        fixed_cost_per_month_cents: snapshot.dig(:fixedCost, :perMonthCents),
        fixed_cost_per_unit_at_volume_cents: snapshot.dig(:fixedCost, :perUnitAtVolumeCents),
        created_at: Time.current, updated_at: Time.current
      }
      Array(snapshot[:warnings]).each_with_index do |message, index|
        warning_rows << {
          id: SecureRandom.uuid, pricing_scenario_result_id: result_id,
          position: index, message: message.to_s,
          created_at: Time.current, updated_at: Time.current
        }
      end
    end
    insert_rows(:pricing_scenario_results, rows)
    insert_rows(:pricing_scenario_warnings, warning_rows)
  end

  def backfill_risk_notification_payload
    conn = routed_connection(:risk_notifications)
    routed_select_all(:risk_notifications, 'SELECT id, payload FROM risk_notifications WHERE payload IS NOT NULL').each do |row|
      payload = parse_json(row['payload'])
      next unless payload.is_a?(Hash)

      payload = payload.stringify_keys
      attrs = {
        source: payload['source'],
        country_code: payload['countryCode'],
        event_type: payload['eventType'],
        risk_score: payload['riskScore'],
        risk_level: payload['riskLevel']
      }
      updates = attrs.compact.map { |k, v| "#{conn.quote_column_name(k)} = #{conn.quote(v)}" }.join(', ')
      next if updates.empty?

      routed_execute(:risk_notifications, "UPDATE risk_notifications SET #{updates} WHERE id = #{conn.quote(row['id'])}")
    end
  end

  # --- Reverse backfills (relational -> JSON), for the down migration ------

  def reverse_backfills
    reverse_cost_template_items
    reverse_risk_assessment_details
    reverse_risk_event_metadata
    reverse_sanctions_children
    reverse_audit_log_children
    reverse_pricing_scenario_results
    reverse_risk_notification_payload
  end

  def reverse_cost_template_items
    conn = routed_connection(:cost_templates)
    routed_select_all(:cost_template_items, 'SELECT cost_template_id, position, category, name, amount_cents, is_recurring, notes, employee, role, hours, hourly_rate_cents, allocation_basis FROM cost_template_items ORDER BY cost_template_id, position').group_by { |r| r['cost_template_id'] }.each do |template_id, rows|
      items = rows.map do |r|
        {
          category: r['category'], name: r['name'], amount_cents: r['amount_cents'],
          is_recurring: r['is_recurring'], notes: r['notes'], employee: r['employee'],
          role: r['role'], hours: r['hours'], hourly_rate_cents: r['hourly_rate_cents'],
          allocation_basis: r['allocation_basis']
        }.compact
      end
      routed_execute(:cost_templates, "UPDATE cost_templates SET items = #{conn.quote(items.to_json)} WHERE id = #{conn.quote(template_id)}")
    end
  end

  def reverse_risk_assessment_details
    conn = routed_connection(:risk_assessments)
    routed_select_all(:risk_assessment_dimensions, 'SELECT risk_assessment_id, dimension_key, score FROM risk_assessment_dimensions ORDER BY position').group_by { |r| r['risk_assessment_id'] }.each do |assessment_id, rows|
      dimensions = rows.each_with_object({}) { |r, h| h[r['dimension_key']] = r['score'] }
      routed_execute(:risk_assessments, "UPDATE risk_assessments SET dimensions = #{conn.quote(dimensions.to_json)} WHERE id = #{conn.quote(assessment_id)}")
    end

    routed_select_all(:risk_assessment_data_sources, 'SELECT risk_assessment_id, name FROM risk_assessment_data_sources ORDER BY position').group_by { |r| r['risk_assessment_id'] }.each do |assessment_id, rows|
      sources = rows.map { |r| r['name'] }
      routed_execute(:risk_assessments, "UPDATE risk_assessments SET data_sources = #{conn.quote(sources.to_json)} WHERE id = #{conn.quote(assessment_id)}")
    end
  end

  def reverse_risk_event_metadata
    conn = routed_connection(:risk_events)
    routed_select_all(:risk_event_metadata, 'SELECT risk_event_id, key, value FROM risk_event_metadata ORDER BY position').group_by { |r| r['risk_event_id'] }.each do |event_id, rows|
      metadata = rows.each_with_object({}) { |r, h| h[r['key']] = parse_json(r['value']) }
      routed_execute(:risk_events, "UPDATE risk_events SET metadata = #{conn.quote(metadata.to_json)} WHERE id = #{conn.quote(event_id)}")
    end
  end

  def reverse_sanctions_children
    conn = routed_connection(:sanctions_entries)
    routed_select_all(:sanctions_entry_aliases, 'SELECT sanctions_entry_id, name FROM sanctions_entry_aliases ORDER BY position').group_by { |r| r['sanctions_entry_id'] }.each do |entry_id, rows|
      aliases = rows.map { |r| r['name'] }
      routed_execute(:sanctions_entries, "UPDATE sanctions_entries SET aliases = #{conn.quote(aliases.to_json)} WHERE id = #{conn.quote(entry_id)}")
    end

    routed_select_all(:sanctions_entry_identifiers, 'SELECT sanctions_entry_id, identifier_type, value FROM sanctions_entry_identifiers ORDER BY position').group_by { |r| r['sanctions_entry_id'] }.each do |entry_id, rows|
      identifiers = rows.each_with_object({}) { |r, h| h[r['identifier_type']] = r['value'] }
      routed_execute(:sanctions_entries, "UPDATE sanctions_entries SET identifiers = #{conn.quote(identifiers.to_json)} WHERE id = #{conn.quote(entry_id)}")
    end
  end

  def reverse_audit_log_children
    conn = routed_connection(:audit_logs)
    routed_select_all(:audit_log_changes, 'SELECT audit_log_id, attribute_name, old_value, new_value FROM audit_log_changes ORDER BY position').group_by { |r| r['audit_log_id'] }.each do |log_id, rows|
      changes = rows.each_with_object({}) do |r, h|
        h[r['attribute_name']] = { 'from' => parse_json(r['old_value']), 'to' => parse_json(r['new_value']) }
      end
      routed_execute(:audit_logs, "UPDATE audit_logs SET changeset = #{conn.quote(changes.to_json)} WHERE id = #{conn.quote(log_id)}")
    end

    routed_select_all(:audit_log_metadata, 'SELECT audit_log_id, key, value FROM audit_log_metadata ORDER BY position').group_by { |r| r['audit_log_id'] }.each do |log_id, rows|
      metadata = rows.each_with_object({}) { |r, h| h[r['key']] = parse_json(r['value']) }
      routed_execute(:audit_logs, "UPDATE audit_logs SET changeset = #{conn.quote(metadata.to_json)} WHERE id = #{conn.quote(log_id)} AND changeset IS NULL")
    end
  end

  def reverse_pricing_scenario_results
    conn = routed_connection(:pricing_scenarios)
    routed_select_all(:pricing_scenario_results, 'SELECT * FROM pricing_scenario_results').each do |r|
      warnings = routed_select_all(:pricing_scenario_warnings, "SELECT message FROM pricing_scenario_warnings WHERE pricing_scenario_result_id = #{conn.quote(r['id'])} ORDER BY position").map { |w| w['message'] }
      snapshot = {
        target: { priceCents: r['target_price_cents'], includesTax: r['target_includes_tax'],
                  netCents: r['target_net_cents'], grossCents: r['target_gross_cents'] },
        calculated: { netCents: r['calculated_net_cents'], grossCents: r['calculated_gross_cents'] },
        profit: { perUnitNetCents: r['profit_per_unit_net_cents'],
                  perUnitGrossCents: r['profit_per_unit_gross_cents'], marginPct: r['profit_margin_pct'],
                  markupPct: r['profit_markup_pct'],
                  contributionMarginPerUnitCents: r['profit_contribution_margin_per_unit_cents'],
                  contributionMarginRatioPct: r['profit_contribution_margin_ratio_pct'],
                  variableCostPerUnitCents: r['profit_variable_cost_per_unit_cents'],
                  fullCostPerUnitCents: r['profit_full_cost_per_unit_cents'] },
        revenue: { monthlyNetCents: r['revenue_monthly_net_cents'],
                   monthlyGrossCents: r['revenue_monthly_gross_cents'],
                   batchNetCents: r['revenue_batch_net_cents'], batchGrossCents: r['revenue_batch_gross_cents'] },
        monthlyProfit: { netCents: r['monthly_profit_net_cents'], marginPct: r['monthly_profit_margin_pct'],
                         unitsPerMonth: r['monthly_profit_units_per_month'] },
        breakEven: { unitsPerMonth: r['break_even_units_per_month'],
                     revenueNetCents: r['break_even_revenue_net_cents'], feasible: r['break_even_feasible'],
                     reason: r['break_even_reason'], coverageRatioPct: r['break_even_coverage_ratio_pct'],
                     currentVolume: r['break_even_current_volume'] },
        variableCost: { perUnitCents: r['variable_cost_per_unit_cents'],
                        shareOfPricePct: r['variable_cost_share_of_price_pct'] },
        fixedCost: { perMonthCents: r['fixed_cost_per_month_cents'],
                     perUnitAtVolumeCents: r['fixed_cost_per_unit_at_volume_cents'] },
        warnings: warnings
      }
      routed_execute(:pricing_scenarios, "UPDATE pricing_scenarios SET result_snapshot = #{conn.quote(snapshot.to_json)} WHERE id = #{conn.quote(r['pricing_scenario_id'])}")
    end
  end

  def reverse_risk_notification_payload
    conn = routed_connection(:risk_notifications)
    routed_select_all(:risk_notifications, 'SELECT id, kind, material_id, risk_event_id, source, country_code, event_type, risk_score, risk_level FROM risk_notifications').each do |r|
      payload =
        if r['kind'] == 'critical_material'
          { riskScore: r['risk_score'], riskLevel: r['risk_level'], materialId: r['material_id'] }.compact
        else
          { source: r['source'], countryCode: r['country_code'], eventType: r['event_type'],
            materialId: r['material_id'], riskEventId: r['risk_event_id'] }.compact
        end
      routed_execute(:risk_notifications, "UPDATE risk_notifications SET payload = #{conn.quote(payload.to_json)} WHERE id = #{conn.quote(r['id'])}")
    end
  end

  # --- Generic helpers -----------------------------------------------------

  def insert_rows(table, rows)
    return if rows.empty?

    conn = routed_connection(table)
    columns = rows.first.keys
    quoted_columns = columns.map { |c| conn.quote_column_name(c) }.join(', ')
    rows.each_slice(200) do |batch|
      values = batch.map do |row|
        "(#{columns.map { |c| conn.quote(row[c]) }.join(', ')})"
      end.join(', ')
      conn.execute("INSERT INTO #{conn.quote_table_name(table)} (#{quoted_columns}) VALUES #{values}")
    end
  end

  def parse_json(value)
    return nil if value.blank?

    JSON.parse(value)
  rescue JSON::ParserError, TypeError
    nil
  end

  def presence(value, fallback)
    value.to_s.presence || fallback
  end

  def cents(value)
    return 0 if value.nil?

    BigDecimal(value.to_s).round(0, half: :up).to_i
  end
end
