# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DatabaseSetup::Seeder do
  it 'loads the seed file and returns the resulting record counts' do
    allow(Rails.application).to receive(:load_seed)
    allow(User).to receive(:count).and_return(1)
    allow(Project).to receive(:count).and_return(2)
    allow(Material).to receive(:count).and_return(3)

    expect(described_class.call).to eq(users: 1, projects: 2, materials: 3)
    expect(Rails.application).to have_received(:load_seed)
  end
end
