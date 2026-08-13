RSpec.describe 'configuration' do
  around do |example|
    PolyId.reset
    example.run
  ensure
    PolyId.reset
  end

  describe 'once a model has resolved its config' do
    before { User.polyid? }

    it 'refuses settings that are baked into models' do
      expect { PolyId.auto_detect = false }.to raise_error(PolyId::ConfigurationError, /initializer/)
      expect { PolyId.default_uuid_attribute = :public_id }.to raise_error(PolyId::ConfigurationError)
    end

    it 'still allows settings that are read afresh' do
      expect { PolyId.cache_ttl = 1.hour }.not_to raise_error
      expect { PolyId.uuid_generator = :v4 }.not_to raise_error
      expect { PolyId.cache = ActiveSupport::Cache::MemoryStore.new }.not_to raise_error
    end

    it 'refuses a late polyid declaration, rather than ignoring it' do
      expect {
        User.polyid uuid_attribute: :something_else
      }.to raise_error(PolyId::ConfigurationError, /already resolved/)
    end
  end

  describe 'before any model has resolved' do
    it 'accepts configuration' do
      expect { PolyId.auto_detect = false }.not_to raise_error
      expect(PolyId.auto_detect?).to be false
    end
  end

  describe '.reset' do
    it 'makes configuration settable again' do
      User.polyid?
      expect { PolyId.auto_detect = false }.to raise_error(PolyId::ConfigurationError)

      PolyId.reset

      expect { PolyId.auto_detect = false }.not_to raise_error
    end

    it 'drops resolved model config so new settings take effect' do
      expect(User.polyid?).to be true

      PolyId.reset
      PolyId.auto_detect = false

      expect(User.polyid?).to be false
    end
  end
end
