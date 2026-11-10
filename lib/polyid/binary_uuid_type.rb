module PolyId
  class BinaryUuidType < ActiveModel::Type::Binary # :nodoc:
    def initialize(subtype = nil)
      super()
      @subtype = subtype
    end

    def cast(value)
      return if value.nil?

      if binary_uuid_bytes?(value)
        unpack_uuid(value)
      else
        valid_uuid(value)
      end
    end

    def serialize(value)
      return if value.nil?
      return super(value) if binary_uuid_bytes?(value)

      uuid = valid_uuid(value)
      super(pack_uuid(uuid)) if uuid
    end

    def serialize_cast_value(value)
      serialize(value)
    end

    def deserialize(value)
      return if value.nil?

      # the adapter's own encoding, eg. postgres reads bytea as escaped text
      value = @subtype.deserialize(value) if @subtype
      unpack_uuid(value)
    end

    private

    def unpack_uuid(value)
      bytes = value.is_a?(Data) ? value.to_s : value
      return bytes unless binary_uuid_bytes?(bytes)

      bytes.unpack("H8H4H4H4H12").join("-")
    end

    # strict, unlike PolyId.normalize_uuid: only an RFC uuid is stored
    def valid_uuid(value)
      uuid = value.to_s
      uuid if PolyId.uuid?(uuid)
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
