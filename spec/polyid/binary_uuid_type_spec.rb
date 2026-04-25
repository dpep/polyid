RSpec.describe PolyId::BinaryUuidType do
  subject(:type) { described_class.new }

  let(:uuid) { SecureRandom.uuid }
  let(:undashed_uuid) { uuid.delete("-") }
  let(:binary_uuid) { [uuid.delete("-")].pack("H*") }
  let(:invalid_variant_binary_uuid) do
    binary_uuid.setbyte(8, binary_uuid.getbyte(8) & 0b0011_1111)
  end
  let(:invalid_version_binary_uuid) do
    binary_uuid.setbyte(6, binary_uuid.getbyte(6) & 0b0000_1111)
  end

  describe "#cast" do
    it "returns nil for nil" do
      expect(type.cast(nil)).to be_nil
    end

    it "returns a dashed uuid string for a uuid string" do
      expect(type.cast(uuid)).to eq(uuid)
    end

    it "returns a dashed uuid string for an undashed uuid string" do
      expect(type.cast(undashed_uuid)).to eq(uuid)
    end

    it "deserializes raw 16-byte binary uuid data" do
      expect(type.cast(binary_uuid)).to eq(uuid)
    end

    it "raises for 16-byte data with a non-rfc4122 variant" do
      expect {
        type.cast(invalid_variant_binary_uuid)
      }.to raise_error(ArgumentError, /invalid uuid/)
    end

    it "raises for 16-byte data with an invalid version nibble" do
      expect {
        type.cast(invalid_version_binary_uuid)
      }.to raise_error(ArgumentError, /invalid uuid/)
    end

    it "raises for an invalid string" do
      expect {
        type.cast("abc")
      }.to raise_error(ArgumentError, /invalid uuid/)
    end

    it "raises for a non-uuid non-binary value" do
      expect {
        type.cast(123)
      }.to raise_error(ArgumentError, /invalid uuid/)
    end
  end

  describe "#serialize" do
    it "returns nil for nil" do
      expect(type.serialize(nil)).to be_nil
    end

    it "serializes a dashed uuid string to binary data" do
      serialized = type.serialize(uuid)

      expect(serialized).to be_a(ActiveModel::Type::Binary::Data)
      expect(serialized.to_s.bytesize).to eq(16)
      expect(serialized.to_s).to eq(binary_uuid)
    end

    it "serializes an undashed uuid string to binary data" do
      serialized = type.serialize(undashed_uuid)

      expect(serialized).to be_a(ActiveModel::Type::Binary::Data)
      expect(serialized.to_s).to eq(binary_uuid)
    end

    it "passes through already-packed binary uuid data" do
      serialized = type.serialize(binary_uuid)

      expect(serialized.to_s).to eq(binary_uuid)
    end

    it "raises for 16-byte data with a non-rfc4122 variant" do
      expect {
        type.serialize(invalid_variant_binary_uuid)
      }.to raise_error(ArgumentError, /invalid uuid/)
    end

    it "raises for an invalid string" do
      expect {
        type.serialize("abc")
      }.to raise_error(ArgumentError, /invalid uuid/)
    end
  end

  describe "#deserialize" do
    it "returns nil for nil" do
      expect(type.deserialize(nil)).to be_nil
    end

    it "deserializes raw binary uuid data to a dashed uuid string" do
      expect(type.deserialize(binary_uuid)).to eq(uuid)
    end

    it "deserializes ActiveModel binary wrapper data" do
      value = ActiveModel::Type::Binary::Data.new(binary_uuid)

      expect(type.deserialize(value)).to eq(uuid)
    end

    it "passes through 16-byte data with a non-rfc4122 variant" do
      expect(type.deserialize(invalid_variant_binary_uuid)).to eq(invalid_variant_binary_uuid)
    end

    it "passes through non-binary strings" do
      expect(type.deserialize(uuid)).to eq(uuid)
    end

    it "normalizes undashed uuid strings to dashed format" do
      expect(type.deserialize(undashed_uuid)).to eq(uuid)
    end

    it "passes through strings that are not uuid-shaped" do
      expect(type.deserialize("abc")).to eq("abc")
    end
  end
end
