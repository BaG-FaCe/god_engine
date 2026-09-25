# Shared state hygiene.
#
# Rails.cache in test is the in-process memory store (see
# config/environments/test.rb) and caches provider responses *per TTL*, so a
# value written by one example would leak into the next. The same is true for
# the reference data modules that memoise their YAML files.
RSpec.configure do |config|
  config.before do
    Rails.cache.clear
    SupplyChainRisk::Infrastructure::Providers::FreeData::Support.reload!
    SupplyChainRisk::Infrastructure::Providers::FreeData::PortCongestionProvider.reload!
  end
end
