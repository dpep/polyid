module PolyId
  module CollectionAssociation
    # a loaded inverse_of association scans its records by id, never reaching Relation#find
    def find(*args)
      return super unless options[:inverse_of] && loaded? && klass.polyid?

      super(*klass.polyid_translate_find_args(args))
    end

    # user_ids= integer-casts each id before it queries, so translate first
    def ids_writer(ids)
      return super unless klass.polyid? && reflection.association_primary_key == klass.primary_key

      super(klass.polyid_translate_find_args(Array(ids)))
    end
  end
end
