require 'rails_helper'

# Provider contract tests (Update-Prompt Aufgabe 3 + 4).
#
# Every implementation of `SupplyChainRisk::Domain::RiskDataProvider` has to pass
# the *same* assertions, regardless of tier: the rest of the application must not
# be able to tell a free open-data feed from a commercial platform.
#
# Recorded responses live in `spec/fixtures/risk/*.json` (the VCR "cassette" per
# provider) and are installed through `RiskProviderContract.stub!`, so no test in
# this file ever opens a socket.
RSpec.describe 'RiskDataProvider contract' do
  # --- free / open data ------------------------------------------------------
  context 'with the open-data providers (fresh fixture responses)' do
    %w[world_bank_lpi gdacs usgs_earthquake open_meteo ecb_fx].each do |key|
      it_behaves_like 'a risk data provider', key
    end

    it_behaves_like 'a risk data provider', 'openweather_alerts', api_key: 'fixture-key'
    it_behaves_like 'a risk data provider', 'fred_economic', api_key: 'fixture-key'
    it_behaves_like 'a risk data provider', 'freightos_fbx', api_key: 'fixture-key'
    it_behaves_like 'a risk data provider', 'un_comtrade'
    it_behaves_like 'a risk data provider', 'reliefweb'
    it_behaves_like 'a risk data provider', 'eu_taric'
  end

  # --- database / reference-data backed -------------------------------------
  context 'with the providers that read local reference data' do
    it_behaves_like 'a risk data provider', 'eu_sanctions'
    it_behaves_like 'a risk data provider', 'ofac_sdn'
    it_behaves_like 'a risk data provider', 'port_congestion'
  end

  # --- internal -------------------------------------------------------------
  context 'with the always-available internal providers' do
    it_behaves_like 'a risk data provider', 'heuristic'

    # The manual fallback legitimately answers nil when no Ampel was maintained.
    it_behaves_like 'a risk data provider', 'manual', draft_expected: false
  end

  # --- paid -----------------------------------------------------------------
  context 'with paid adapters that have no key configured' do
    SupplyChainRisk::Infrastructure::ProviderCatalogue.paid.map(&:key).each do |key|
      it_behaves_like 'a risk data provider', key, draft_expected: false
    end
  end

  # Aufgabe 4: the harness must be enough to contract-test a *new* paid adapter.
  # project44 only supplies its HTTP mapping; everything else comes from the
  # shared examples above.
  context 'with a paid adapter that has a configured key' do
    it_behaves_like 'a risk data provider', 'project44', api_key: 'fixture-key'
  end

  # --- harness guard --------------------------------------------------------
  describe 'harness coverage' do
    it 'covers every provider that runs without a key with a recording or an explicit opt-out' do
      active = SupplyChainRisk::Infrastructure::ProviderCatalogue.all
                              .reject(&:paid?).map(&:key)
      uncovered = active - RiskProviderContract::RECORDINGS.keys - RiskProviderContract::NO_HTTP_NEEDED

      expect(uncovered).to be_empty,
                           "Provider ohne Contract-Fixture: #{uncovered.inspect} " \
                           '(in RiskProviderContract::RECORDINGS ergaenzen)'
    end

    it 'refuses unstubbed outbound requests instead of hitting the network' do
      error_class = defined?(VCR::Errors::UnhandledHTTPRequestError) ? VCR::Errors::UnhandledHTTPRequestError : WebMock::NetConnectNotAllowedError
      expect { Net::HTTP.get(URI('https://unregistered-host.example.com/')) }
        .to raise_error(error_class)
    end
  end
end
