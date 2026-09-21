# Seeds — admin user + demo project with materials, costs and risk data.
# Idempotent: safe to run repeatedly (`bin/rails db:seed`).
admin = User.find_or_create_by!(email: 'admin@god-engine.local') do |user|
  user.name = 'Administrator'
  user.role = 'admin'
  user.password = 'GodEngine-Admin-123'
  user.active = true
end

project = Project.find_or_create_by!(name: 'Produkt A (Demo)') do |record|
  record.description = 'Demonstrationsprojekt mit Lieferrisiko-Bewertung'
  record.status = 'active'
  record.tax_rate = 0.19
  record.country = 'DE'
  record.currency = 'EUR'
  record.units_per_month = 500
  record.batch_size = 100
  record.target_margin_pct = 0.25
  record.owner = admin
end
OverheadRule::DEFAULT_RULES.each do |rule|
  project.overhead_rules.find_or_create_by!(key: rule[:key]) { |r| r.assign_attributes(rule) }
end

supplier = project.suppliers.find_or_create_by!(name: 'Muster GmbH') do |record|
  record.country = 'DE'
  record.city = 'Duisburg'
  record.rating = 4
end

aluminium = project.materials.find_or_create_by!(name: 'Aluminium Profil 2020') do |record|
  record.material_type = 'raw_material'
  record.supplier = supplier
  record.article_number = 'ALU-2020-1000'
  record.unit = 'Stk'
  record.unit_price_cents = 450
  record.quantity = 4
  record.lead_time_value = 14
  record.lead_time_unit = 'days'
  record.stock_quantity = 125
  record.reorder_level = 50
end
if aluminium.material_risk_profile.nil?
  aluminium.create_material_risk_profile!(
    origin_country: 'DE', shipping_route: 'Rotterdam-Duisburg', transport_mode: 'road'
  )
end

chip = project.materials.find_or_create_by!(name: 'Steuerplatine v3') do |record|
  record.material_type = 'electronics'
  record.supplier = supplier
  record.article_number = 'PCB-003'
  record.unit = 'Stk'
  record.unit_price_cents = 1250
  record.quantity = 1
  record.lead_time_value = 6
  record.lead_time_unit = 'weeks'
  record.stock_quantity = 40
  record.reorder_level = 20
end
if chip.material_risk_profile.nil?
  chip.create_material_risk_profile!(
    origin_country: 'CN', hs_code: '85340090', shipping_route: 'CN-SHA -> DE-HAM',
    transport_mode: 'sea', is_single_source: true, freight_cost_trend: 'rising'
  )
  chip.material_risk_profile.record_manual_assessment!(
    level: 'yellow', note: 'Single Source, Seetransport — beobachten', user: admin
  )
end

{ 'rent' => ['Werkstattmiete', 120_000], 'energy' => ['Strom', 18_500],
  'hosting' => ['Shop-Hosting', 2_900] }.each do |category, (name, cents)|
  project.monthly_costs.find_or_create_by!(name: name) do |record|
    record.category = category
    record.amount_cents = cents
  end
end

project.labor_costs.find_or_create_by!(employee: 'Fertigung') do |record|
  record.hours = 2.5
  record.hourly_rate_cents = 4500
end
project.fixed_costs.find_or_create_by!(name: 'Werkzeugkosten') do |record|
  record.category = 'development'
  record.amount_cents = 50_000
  record.allocation_basis = 'per_unit'
end
project.sales_forecasts.find_or_create_by!(period: '2026-09') do |record|
  record.forecast_units = 500
  record.actual_units = 480
end
project.sales_forecasts.find_or_create_by!(period: '2026-10') { |record| record.forecast_units = 550 }

# Initial risk assessment per material so the dashboard shows data on day one.
[aluminium, chip].each do |material|
  next if material.risk_assessments.exists?

  draft = SupplyChainRisk::Infrastructure::Providers::Internal::HeuristicProvider.new.assess(
    SupplyChainRisk::Domain::Subject.from_material(material)
  )
  next if draft.nil?

  assessment = RiskAssessment.create!(draft.to_assessment_attributes(material_id: material.id))
  material.update_columns(risk_score: assessment.risk_score, risk_level: assessment.risk_level,
                          last_risk_checked_at: assessment.fetched_at, updated_at: Time.current)
end

puts "Seeded #{Project.count} project(s), #{Material.count} material(s), " \
     "#{RiskAssessment.count} assessment(s); admin=#{admin.email}"
