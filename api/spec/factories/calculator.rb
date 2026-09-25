FactoryBot.define do
  factory :supplier do
    project
    sequence(:name) { |n| "Lieferant #{n} GmbH" }
    country { 'CN' }
    rating { 3 }
    is_single_source { false }
    sanctions_status { 'unknown' }
  end

  factory :material do
    project
    sequence(:name) { |n| "Material #{n}" }
    material_type { 'component' }
    unit { 'Stk' }
    currency { 'EUR' }
    unit_price_cents { 1250 }
    price_includes_tax { false }
    quantity { 10 }
    min_order_quantity { 5 }
    stock_quantity { 20 }
    reorder_level { 5 }
    lead_time_value { 21 }
    lead_time_unit { 'days' }
    risk_score { nil }
    risk_level { nil }

    trait :with_risk_profile do
      after(:create) { |material| create(:material_risk_profile, material: material) }
    end

    trait :critical do
      risk_score { 82 }
      risk_level { 'high' }
    end
  end

  factory :material_risk_profile do
    material
    origin_country { 'CN' }
    hs_code { '84818099' }
    shipping_route { 'CN-SHA -> DE-HAM' }
    transport_mode { 'sea' }
    freight_cost_trend { 'stable' }
    is_single_source { false }
    historical_delay_count { 1 }
    historical_delay_days { 3 }
  end

  factory :alternative_supplier do
    material
    sequence(:name) { |n| "Alternativlieferant #{n}" }
    country { 'PL' }
    unit_price_cents { 1400 }
    lead_time_days { 14 }
    priority { 1 }
  end
end
