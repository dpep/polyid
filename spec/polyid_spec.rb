RSpec.describe PolyId do
  describe '.cache_binary_uuids?' do
    subject(:cache_binary_uuids?) { described_class.cache_binary_uuids? }

    it { is_expected.to be false }

    context 'when set to true' do
      before { described_class.cache_binary_uuids = true }

      it { is_expected.to be true }
    end

    context 'when set to false' do
      before { described_class.cache_binary_uuids = false }

      it { is_expected.to be false }
    end

    context 'when run in a Rails app' do
      before do
        stub_const("Rails", double(env: double(production?: prod)))
      end

      context 'when in prod' do
        let(:prod) { true }

        it { is_expected.to be true }

        context 'when set to false explicitly' do
          before { described_class.cache_binary_uuids = false }

          it { is_expected.to be false }
        end
      end

      context 'when in dev' do
        let(:prod) { false }

        it { is_expected.to be false }
      end
    end
  end

  describe '.reset' do
    it 'clears cache configuration back to defaults' do
      expect(described_class.cache).to be_a(ActiveSupport::Cache::NullStore)
      described_class.cache.write("abc", 123)
      described_class.cache_binary_uuids = true

      described_class.reset

      expect(described_class.cache).to be_a(ActiveSupport::Cache::MemoryStore)
      expect(described_class.cache).to be_empty
      expect(described_class.cache_binary_uuids?).to be false
    end
  end

    describe '.is_uuid?' do
      subject(:is_uuid?) { described_class.is_uuid?(value) }

      context 'with a dashed hexadecimal uuid' do
        let(:value) { SecureRandom.uuid }

        it { is_expected.to be true }
      end

      context 'with an undashed hexadecimal uuid' do
        let(:value) { SecureRandom.uuid.delete("-") }

        it { is_expected.to be false }
      end

    context 'with a non-uuid string' do
      let(:value) { "abc" }

      it { is_expected.to be false }
    end

    context 'with a uuid-shaped string with an invalid version nibble' do
      let(:value) { "12345678-1234-0234-8234-123456789abc" }

      it { is_expected.to be false }
    end

    context 'with a uuid-shaped string with an invalid variant nibble' do
      let(:value) { "12345678-1234-1234-7234-123456789abc" }

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
