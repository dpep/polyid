RSpec.describe PolyId do
  describe '.reset' do
    it 'clears cache configuration back to defaults' do
      expect(described_class.cache).to be_a(ActiveSupport::Cache::NullStore)
      described_class.cache.write("abc", 123)
      described_class.default_uuid_attribute = :public_id

      described_class.reset

      expect(described_class.cache).to be_a(ActiveSupport::Cache::MemoryStore)
      expect(described_class.cache).to be_empty
      expect(described_class.default_uuid_attribute).to eq('uuid')
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
