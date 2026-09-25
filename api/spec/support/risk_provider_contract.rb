require 'json'

# Contract-test harness for the `supply-chain-risk` providers
# (Update-Prompt Aufgabe 3 + 4).
#
# Two ideas are combined here:
#
#   1. **recorded responses as data** - `RECORDINGS` maps a provider key to the
#      request(s) it makes and the response file that was recorded for it. Adding
#      a provider means adding one row plus one JSON fixture, never new test code.
#   2. **one shared example group** - `'a risk data provider'` runs the same
#      assertions against every implementation, so a new paid adapter (Aufgabe 4)
#      inherits the whole contract for free and only has to provide its HTTP
#      mapping.
module RiskProviderContract
  FIXTURE_ROOT = Rails.root.join('spec/fixtures/risk')

  # `url` may be a String or a Regexp; `method` defaults to :get. A provider maps
  # to a *list* because several sources need more than one request (ECB compares
  # two dates, project44 authenticates before querying).
  RECORDINGS = {
    'world_bank_lpi' => [
      { url: %r{api\.worldbank\.org/v2/country}, fixture: 'world_bank_lpi' }
    ],
    'gdacs' => [
      { url: %r{gdacs\.org/gdacsapi}, fixture: 'gdacs' }
    ],
    'usgs_earthquake' => [
      { url: %r{earthquake\.usgs\.gov/.*\.geojson}, fixture: 'usgs' }
    ],
    'open_meteo' => [
      { url: %r{api\.open-meteo\.com/v1/forecast}, fixture: 'open_meteo' }
    ],
    'ecb_fx' => [
      { url: %r{api\.frankfurter\.dev/v1/latest}, fixture: 'frankfurter_latest' },
      { url: %r{api\.frankfurter\.dev/v1/\d{4}-\d{2}-\d{2}}, fixture: 'frankfurter_past' }
    ],
    'freightos_fbx' => [
      { url: %r{api\.freightos\.com}, fixture: 'freightos_fbx' }
    ],
    'reliefweb' => [
      { url: %r{api\.reliefweb\.int}, fixture: 'reliefweb', method: :post }
    ],
    'un_comtrade' => [
      { url: %r{comtradeapi\.un\.org}, fixture: 'un_comtrade' }
    ],
    'fred_economic' => [
      { url: %r{api\.stlouisfed\.org}, fixture: 'fred' }
    ],
    'openweather_alerts' => [
      { url: %r{api\.openweathermap\.org}, fixture: 'openweather' }
    ],
    'eu_taric' => [
      { url: %r{taric\.example\.com}, fixture: 'eu_taric' }
    ],
    # A representative paid adapter, so the harness proves itself against the
    # commercial contract as well (Update-Prompt Aufgabe 4). Two hops: OAuth2
    # token, then the assessment endpoint.
    'project44' => [
      { url: %r{api\.project44\.com/api/v4/oauth2/token},
        fixture: 'project44_token', method: :post },
      { url: %r{api\.project44\.com/api/v4/shipments/insights},
        fixture: 'project44_assessment' },
      { url: %r{api\.project44\.com/api/v4/alerts},
        fixture: 'project44_events' }
    ]
  }.freeze

  # Providers whose contract is answered from the database or from reference YAML
  # (or, for paid adapters without a key, not at all). They are excluded from the
  # "every active provider has a recording" guard - explicitly, with a reason.
  NO_HTTP_NEEDED = %w[eu_sanctions ofac_sdn port_congestion heuristic manual].freeze

  # Providers that need a configured endpoint before they can answer.
  CONFIG = {
    'eu_taric' => { 'baseUrl' => 'https://taric.example.com', 'assessmentPath' => '/api/measures' }
  }.freeze

  class << self
    def fixture(name)
      JSON.parse(File.read(FIXTURE_ROOT.join("#{name}.json")))
    end

    # Recorded responses for one provider.
    # @return [Array<Hash>]
    def recordings_for(key)
      value = RECORDINGS[key.to_s]
      return [] if value.nil?

      value.is_a?(Array) ? value : [value]
    end

    # Installs the recorded response(s) for one provider.
    # @return [Boolean] true when at least one stub was installed
    def stub!(key)
      entries = recordings_for(key)
      entries.each do |entry|
        WebMock.stub_request(entry.fetch(:method, :get), entry.fetch(:url))
               .to_return(status: 200,
                          body: JSON.generate(fixture(entry.fetch(:fixture))),
                          headers: { 'Content-Type' => 'application/json' })
      end
      entries.any?
    end

    # Simulates "the provider is down" for every recorded endpoint.
    def stub_failure!(key)
      entries = recordings_for(key)
      entries.each do |entry|
        WebMock.stub_request(entry.fetch(:method, :get), entry.fetch(:url)).to_timeout
      end
      entries.any?
    end

    def config_for(key)
      CONFIG.fetch(key.to_s, {})
    end

    # The one subject every contract test uses - mirrors
    # `RiskDataProvider#probe_subject` so the probe endpoint and the contract test
    # ask exactly the same question.
    def probe_subject
      SupplyChainRisk::Domain::Subject.new(
        material_id: 'contract-material', name: 'Contract-Material', article_number: 'CT-1',
        origin_country: 'CN', destination_country: 'DE', hs_code: '84818099',
        shipping_route: 'CN-SHA -> DE-HAM', transport_mode: 'sea',
        freight_cost_trend: 'stable', supplier_name: 'Contract Supplier',
        is_single_source: true, supplier_rating: 3, lead_time_days: 45,
        historical_delay_count: 2, historical_delay_days: 6,
        last_disruption_at: nil, last_disruption_cause: nil,
        unit_net_price_cents: 1000, manual_level: nil, manual_note: nil
      )
    end
  end
# The shared contract. Every provider implementation - free, internal or paid -
# must satisfy it.
#
# @param key [String] catalogue key of the provider under test
# @param draft_expected [Boolean] false for providers that legitimately answer nil
#   for the shared probe subject (e.g. the manual fallback without an Ampel)
# @param api_key [String, nil] injected as the project-scoped key so a paid
#   adapter can be contract-tested without touching the process environment
RSpec.shared_examples 'a risk data provider' do |key, draft_expected: true, api_key: nil|
  let(:descriptor) { SupplyChainRisk::Infrastructure::ProviderRegistry.find!(key) }
  let(:provider_context) do
    config = RiskProviderContract.config_for(key)
    config = config.merge(api_key: api_key) if api_key
    SupplyChainRisk::Domain::ProviderContext.new(descriptor: descriptor, config: config)
  end
  let(:provider) { descriptor.provider_class.instantiate(context: provider_context) }
  let(:subject_value) { RiskProviderContract.probe_subject }

  before do
    # Provider availability otherwise depends on the developer's environment;
    # pinning the descriptor's env keys to nil keeps the contract deterministic.
    allow(ENV).to receive(:[]).and_call_original
    descriptor.env_keys.each do |env_key|
      allow(ENV).to receive(:[]).with(env_key.to_s).and_return(nil)
    end
    RiskProviderContract.stub!(key)
  end

  it 'is registered with a complete descriptor' do
    expect(descriptor.key).to eq(key)
    expect(descriptor.name).to be_present
    expect(descriptor.tier).to be_in(RiskAssessment::PROVIDER_TIERS)
    expect(descriptor.cache_ttl_minutes).to be_a(Integer).and be >= 0
    expect(descriptor.rate_limit_per_minute).to be_a(Integer).and be >= 0
    expect(descriptor.description).to be_present
  end

  it 'implements the RiskDataProvider contract' do
    expect(provider).to respond_to(:assess, :events, :probe, :available?, :descriptor)
    expect(provider.key).to eq(key)
    expect(provider.tier).to eq(descriptor.tier)
  end

  it 'answers .probe with the documented structure' do
    result = provider.probe

    expect(result).to be_a(Hash)
    expect(result).to include(:ok, :message, :latencyMs)
    expect([true, false]).to include(result[:ok])
    expect(result[:latencyMs]).to be_a(Integer)
    expect(result[:sampleScore]).to be_nil.or be_between(0, 100)
  end

  it 'returns a normalised assessment draft with every mandatory field' do
    draft = provider.assess(subject_value)

    if draft_expected
      expect(draft).to be_a(SupplyChainRisk::Domain::AssessmentDraft)
    else
      expect(draft.nil? || draft.is_a?(SupplyChainRisk::Domain::AssessmentDraft)).to be(true)
    end
    next if draft.nil?

    # Score 0-100, Ampel, Quelle, Zeitstempel, Freitext-Begruendung.
    expect(draft.risk_score).to be_between(0, 100)
    expect(draft.risk_level).to be_in(RiskAssessment::LEVELS)
    expect(draft.provider_key).to eq(key)
    expect(draft.provider_name).to eq(descriptor.name)
    expect(draft.provider_tier).to eq(descriptor.tier)
    expect(draft.data_sources).to be_a(Array).and be_present
    expect(draft.reason).to be_a(String).and be_present
    expect(draft.confidence).to be_nil.or be_between(0, 1)
  end

  it 'produces attributes that persist into a valid risk_assessment row' do
    draft = provider.assess(subject_value)
    next if draft.nil?

    attributes = draft.to_assessment_attributes(material_id: 'contract-material')
    expect(attributes[:material_id]).to eq('contract-material')
    expect(attributes[:provider_key]).to eq(key)
    expect(attributes[:origin]).to eq('automatic')
    expect(attributes[:fetched_at]).to be_present
    expect(attributes[:risk_score]).to be_between(0, 100)
    expect(attributes[:risk_level]).to be_in(RiskAssessment::LEVELS)

    record = RiskAssessment.new(attributes.merge(material: build(:material)))
    expect(record).to be_valid
  end

  it 'returns event drafts (or an empty list) that satisfy the event contract' do
    drafts = provider.events(since: 7.days.ago)

    expect(drafts).to be_a(Array)
    drafts.each do |draft|
      expect(draft).to be_a(SupplyChainRisk::Domain::EventDraft)
      expect(draft.source).to eq(key)
      expect(draft.title).to be_present
      expect(draft.event_type).to be_in(RiskEvent::TYPES)
      expect(draft.severity).to be_in(RiskEvent::SEVERITIES)
      expect(draft.occurred_at).to be_present
    end
  end

  it 'degrades to "no data" instead of raising when the upstream API is unreachable' do
    next unless RiskProviderContract.stub_failure!(key)

    expect { provider.assess(subject_value) }.not_to raise_error
    expect { provider.events_safely(since: 7.days.ago) }.not_to raise_error
  end
end

end
