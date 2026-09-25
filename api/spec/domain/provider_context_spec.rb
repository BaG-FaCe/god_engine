require 'rails_helper'

RSpec.describe SupplyChainRisk::Domain::ProviderContext do
  let(:descriptor) { SupplyChainRisk::Infrastructure::ProviderRegistry.find!('gdacs') }
  let(:context) do
    described_class.new(descriptor: descriptor,
                        cache: ActiveSupport::Cache::MemoryStore.new,
                        logger: Logger.new(IO::NULL))
  end

  describe '#cached' do
    it 'writes the fresh value plus a long-lived stale copy' do
      context.cached('test', 'key') { 'value' }

      expect(context.cached('test', 'key') { raise 'should not be called' }).to eq('value')
      expect(context.cache.read('scr:test:key')).to eq('value')
      expect(context.cache.read('scr:test:key:stale')).to eq('value')
    end

    it 'falls back to the stale copy and flags the read when the upstream is down' do
      context.cached('test', 'key') { 'value' }
      context.cache.delete('scr:test:key') # fresh entry expired

      result = context.cached('test', 'key') do
        raise Shared::Infrastructure::Http::JsonClient::Timeout, 'down'
      end

      expect(result).to eq('value')
      expect(context.last_read_stale?).to be(true)
    end

    it 're-raises when there is no stale copy either' do
      expect do
        context.cached('test', 'key') do
          raise Shared::Infrastructure::Http::JsonClient::Timeout, 'down'
        end
      end.to raise_error(Shared::Infrastructure::Http::JsonClient::Timeout)
      expect(context.last_read_stale?).to be(false)
    end
  end

  describe '#api_key resolution' do
    it 'prefers the project-scoped config key over the environment' do
      descriptor = SupplyChainRisk::Infrastructure::ProviderRegistry.find!('project44')
      configured = described_class.new(descriptor: descriptor, config: { api_key: 'project-key' })

      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('PROJECT44_API_KEY').and_return('env-key')

      expect(configured.api_key).to eq('project-key')
    end
  end
end
