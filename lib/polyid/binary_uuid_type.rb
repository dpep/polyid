module PolyId
  class BinaryUuidType < ActiveModel::Type::Binary
    def cast(value)
      return if value.nil?

      if binary_uuid_bytes?(value)
        deserialize(value)
      else
        normalize_uuid(value)
      end
    end

    def serialize(value)
      return if value.nil?

      bytes = binary_uuid_bytes?(value) ? value : pack_uuid(normalize_uuid(value))
      super(bytes)
    end

    def deserialize(value)
      return if value.nil?

      bytes = value.is_a?(Data) ? value.to_s : value
      return PolyId.normalize_uuid(bytes) || bytes unless binary_uuid_bytes?(bytes)

      bytes.unpack("H8H4H4H4H12").join("-")
    end

    private

    def normalize_uuid(value)
      uuid = PolyId.normalize_uuid(value.to_s)
      raise ArgumentError, "invalid uuid: #{value.inspect}" unless uuid

      uuid
    end

    def pack_uuid(uuid)
      [uuid.delete("-")].pack("H*")
    end

    def binary_uuid_bytes?(value)
      return false unless value.is_a?(String) && value.bytesize == 16

      version = value.getbyte(6) >> 4
      variant = value.getbyte(8) >> 6

      version.between?(1, 8) && variant == 0b10
    end
  end
end
