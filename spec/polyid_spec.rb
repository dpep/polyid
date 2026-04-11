RSpec.describe PolyId do
  describe '.cache_binary_uuids?' do
    subject(:cache_binary_uuids?) { described_class.cache_binary_uuids? }

    it { is_expected.to be false }

    it 'returns an explicit true override when configured' do
      described_class.cache_binary_uuids = true
      expect(cache_binary_uuids?).to be true
    end

    it 'returns an explicit false override when configured' do
      described_class.cache_binary_uuids = false
      expect(cache_binary_uuids?).to be false
    end

    context 'when run in a Rails app' do
      before do
        stub_const("Rails", double(env: double(production?: prod)))
      end

      context 'when in prod' do
        let(:prod) { true }

        it { is_expected.to be true }
      end

      context 'when in dev' do
        let(:prod) { false }

        it { is_expected.to be false }
      end
    end
  end

  describe '.reset' do
    it 'clears cache configuration back to defaults' do
      described_class.cache = ActiveSupport::Cache::MemoryStore.new
      described_class.cache.write("abc", 123)
      described_class.cache_binary_uuids = true

      described_class.reset

      expect(described_class.instance_variable_defined?(:@cache)).to be false
      expect(described_class.instance_variable_defined?(:@cache_binary_uuids)).to be false
      expect(described_class.cache).to be_a(ActiveSupport::Cache::MemoryStore)
      expect(described_class.cache.read("abc")).to be_nil
      expect(described_class.cache_binary_uuids?).to be false
    end
  end

    describe '.is_uuid?' do
      subject(:is_uuid?) { described_class.is_uuid?(value) }

      context 'with a dashed hexadecimal uuid' do
        let(:value) { SecureRandom.uuid }

        it { is_expected.to be true }
      end

    context 'with a non-uuid string' do
      let(:value) { "abc" }

      it { is_expected.to be false }
    end

    context 'with a non-string value' do
      let(:value) { 123 }

      it { is_expected.to be false }
    end

    context 'with nil' do
      let(:value) { nil }

      it { is_expected.to be false }
    end
  end
end
