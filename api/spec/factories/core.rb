FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@god-engine.local" }
    name { 'Testanwender' }
    role { 'manager' }
    password { 'GodEngine-Test-123' }
    active { true }

    trait :admin do
      role { 'admin' }
    end

    trait :viewer do
      role { 'viewer' }
    end
  end

  factory :project do
    sequence(:name) { |n| "Kalkulationsprojekt #{n}" }
    country { 'DE' }
    currency { 'EUR' }
    tax_rate { BigDecimal('0.19') }
    target_margin_pct { BigDecimal('0.25') }
    units_per_month { 100 }
    batch_size { 100 }
    risk_refresh_interval_hours { 24 }
    status { 'active' }
    association :owner, factory: :user
  end
end
