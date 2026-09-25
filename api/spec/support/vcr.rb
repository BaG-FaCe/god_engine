# VCR is available for the messy cases (pagination, multi-request flows) where a
# hand written WebMock stub would be harder to read than a recorded cassette.
#
# `record: :none` is deliberate: a missing cassette fails the example instead of
# quietly hitting the network and writing a new recording. Re-record on purpose
# with `VCR_RECORD=new_episodes`.
require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = Rails.root.join('spec/fixtures/vcr_cassettes').to_s
  config.hook_into :webmock
  config.default_cassette_options = {
    record: ENV['VCR_RECORD'].present? ? ENV['VCR_RECORD'].to_sym : :none,
    allow_playback_repeats: true,
    match_requests_on: %i[method uri]
  }
  config.configure_rspec_metadata!
  config.ignore_localhost = true
end
