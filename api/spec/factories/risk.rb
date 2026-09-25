FactoryBot.define do
  factory :risk_assessment do
    material
    provider_key { 'heuristic' }
    provider_name { 'Internes Risiko-Heuristikmodell' }
    provider_tier { 'internal' }
    risk_score { 42 }
    risk_level { 'medium' }
    origin { 'automatic' }
    dimensions { { 'logistics' => 42, 'operational' => 30 } }
    lead_time_variance_days { nil }
    reason { 'Testbewertung' }
    data_sources { ['Internes Heuristikmodell'] }
    confidence { BigDecimal('0.45') }
    fetched_at { Time.current }
    expires_at { 1.hour.from_now }

    trait :expired do
      fetched_at { 2.days.ago }
      expires_at { 1.day.ago }
    end

    trait :manual do
      provider_key { 'manual' }
      provider_name { 'Manuelle Risikobewertung' }
      provider_tier { 'internal' }
      origin { 'manual' }
      expires_at { nil }
    end
  end

  factory :risk_event do
    project
    material { nil }
    event_type { 'disaster' }
    severity { 'high' }
    source { 'gdacs' }
    sequence(:title) { |n| "GDACS-Ereignis #{n}" }
    description { 'Testereignis' }
    country_code { 'CN' }
    occurred_at { Time.current }
    metadata { { alertLevel: 'Orange' } }

    trait :critical do
      severity { 'critical' }
    end
  end

  factory :risk_notification do
    project
    material { nil }
    risk_event { nil }
    kind { 'risk_event' }
    severity { 'critical' }
    sequence(:title) { |n| "Kritische Risikomeldung #{n}" }
    body { 'Lieferrisiko hoch' }
    payload { { source: 'gdacs' } }
    read_at { nil }

    trait :acknowledged do
      acknowledged_at { Time.current }
      association :acknowledged_by, factory: :user
    end

    trait :dismissed do
      dismissed_at { Time.current }
      association :dismissed_by, factory: :user
    end

    trait :read do
      read_at { Time.current }
    end
  end

  factory :risk_provider_config do
    project
    provider_key { 'gdacs' }
    enabled { true }
    poll_interval_minutes { 30 }
    priority { 20 }
    last_run_status { nil }
    api_key { nil }

    trait :due do
      last_run_at { 2.hours.ago }
    end

    trait :fresh do
      last_run_at { 1.minute.ago }
    end

    trait :disabled do
      enabled { false }
    end
  end

  factory :risk_provider_run do
    provider_key { 'gdacs' }
    status { 'ok' }
    started_at { Time.current }
    finished_at { Time.current }
    duration_ms { 120 }
    requests_made { 1 }
    assessments_written { 0 }
    events_written { 0 }
  end

  factory :sanctions_entry do
    source { 'eu_consolidated' }
    list_name { 'EU Konsolidierte Liste' }
    sequence(:entity_name) { |n| "Listed Entity #{n} Ltd" }
    normalised_name { |entry| SanctionsEntry.normalise(entry.entity_name) }
    entity_type { 'entity' }
    country_code { 'RU' }
    program { 'Testprogramm' }
  end
end
