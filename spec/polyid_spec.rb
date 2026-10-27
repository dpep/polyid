RSpec.describe PolyId do
  describe ".reset" do
    it "clears cache configuration back to defaults" do
      expect(described_class.cache).to be_a(ActiveSupport::Cache::NullStore)
      described_class.default_uuid_attribute = :public_id

      described_class.reset

      expect(described_class.cache).to be_a(ActiveSupport::Cache::MemoryStore)
      expect(described_class.default_uuid_attribute).to eq("uuid")
    end

    it "leaves a shared cache store's contents alone" do
      shared = ActiveSupport::Cache::MemoryStore.new
      shared.write("app", 1)
      described_class.cache = shared

      described_class.reset

      expect(shared.read("app")).to eq(1)
    end
  end

  describe ".generate_uuid" do
    it "generates v7 by default" do
      expect(described_class.generate_uuid[14]).to eq("7")
    end

    it "generates v4 on request" do
      expect(described_class.generate_uuid(:v4)[14]).to eq("4")
    end

    it "calls a custom generator" do
      expect(described_class.generate_uuid(-> { "custom" })).to eq("custom")
    end

    it "rejects an unknown generator" do
      expect { described_class.generate_uuid(:v9) }.to raise_error(ArgumentError, /unsupported/)
    end
  end

  describe ".uuid?" do
    subject(:uuid?) { described_class.uuid?(value) }

    it "is aliased as is_uuid?" do
      expect(described_class.is_uuid?(SecureRandom.uuid)).to be true
    end

    context "with a dashed hexadecimal uuid" do
      let(:value) { SecureRandom.uuid }

      it { is_expected.to be true }
    end

    context "with an undashed hexadecimal uuid" do
      let(:value) { SecureRandom.uuid.delete("-") }

      it { is_expected.to be false }
    end

    context "with a non-uuid string" do
      let(:value) { "abc" }

      it { is_expected.to be false }
    end

    context "with a uuid-shaped string with an invalid version nibble" do
      let(:value) { "12345678-1234-0234-8234-123456789abc" }

      it { is_expected.to be false }
    end

    context "with a uuid-shaped string with an invalid variant nibble" do
      let(:value) { "12345678-1234-1234-7234-123456789abc" }

      it { is_expected.to be false }
    end

    context "with a non-string value" do
      let(:value) { 123 }

      it { is_expected.to be false }
    end

    context "with nil" do
      let(:value) { nil }

      it { is_expected.to be false }
    end
  end
end
