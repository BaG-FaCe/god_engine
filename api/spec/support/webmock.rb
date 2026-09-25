# Outbound HTTP is stubbed everywhere. Provider adapters talk to real third party
# services, some of them rate limited or contract gated, so a test that
# accidentally opens a socket is a bug - not a flaky test.
#
# `localhost` stays allowed so health checks and the Rack host check keep
# working; every external host must be stubbed explicitly (WebMock) or served
# from a checked-in cassette (VCR).
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.before do
    WebMock.reset!
  end
end
