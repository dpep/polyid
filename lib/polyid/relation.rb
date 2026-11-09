module PolyId
  # accept UUIDs wherever the primary key is expected
  module Relation
    def find(*ids)
      return super if block_given?
      return super unless klass.polyid?

      super(*klass.polyid_translate_find_args(ids))
    end

    # `where`, `where.not`, and `rewhere` all funnel through here.
    # public to match ActiveRecord, which calls it with an explicit receiver.
    def build_where_clause(opts, rest = [])
      # as ActiveRecord does, so permitted params arrive as a Hash
      opts = sanitize_forbidden_attributes(opts)
      return super unless opts.is_a?(Hash)

      super(klass.polyid_translate_conditions(opts), rest)
    end

    # find_by translates on its own, but the create/new would write raw uuids
    def find_or_create_by(attributes, &) = super(polyid_translate_attributes(attributes), &)
    def find_or_create_by!(attributes, &) = super(polyid_translate_attributes(attributes), &)
    def create_or_find_by(attributes, &) = super(polyid_translate_attributes(attributes), &)
    def create_or_find_by!(attributes, &) = super(polyid_translate_attributes(attributes), &)
    def find_or_initialize_by(attributes, &) = super(polyid_translate_attributes(attributes), &)

    private

    def polyid_translate_attributes(attributes)
      return attributes unless attributes.is_a?(Hash)

      klass.polyid_translate_conditions(attributes).to_h do |key, value|
        [value.equal?(attributes[key]) ? key : polyid_foreign_key(key), value]
      end
    end

    # a create can't assign an id to the association itself
    def polyid_foreign_key(key)
      reflection = klass.reflect_on_association(key)
      reflection&.belongs_to? ? reflection.foreign_key : key
    end
  end
end
