module PolyId
  class UntranslatedUuidError < ArgumentError; end

  # extended onto a copy of an integer key's type, so a uuid that escapes
  # translation raises instead of integer-casting into an unrelated id
  # ("8f47..." => 8).  not a wrapper: QueryAttribute#nil? treats a type that
  # responds to subtype as nullable, so where(account_id: "abc") would match
  # rows with no foreign key
  module IntegerGuard # :nodoc:
    def polyid_guard(model, column)
      @polyid_model = model
      @polyid_column = column
      self
    end

    def cast(value) = super(polyid_refuse_uuid(value))
    def serialize(value) = super(polyid_refuse_uuid(value))

    private

    # resolves the key's target only for a uuid, so ordinary values stay cheap
    def polyid_refuse_uuid(value)
      return value unless PolyId.normalize_uuid(value) && @polyid_model.polyid_key_target(@polyid_column)&.polyid?

      raise UntranslatedUuidError,
        "uuid #{value.inspect} reached #{@polyid_model.table_name}.#{@polyid_column} untranslated; pass an id here"
    end
  end
end
