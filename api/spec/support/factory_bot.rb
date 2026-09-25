# FactoryBot wiring. Factories live in `spec/factories` and are used through the
# short syntax (`create(:material)`), which `rails_helper.rb` mixes in.
RSpec.configure do |config|
  config.before(:suite) do
    FactoryBot.reload
  end
end
