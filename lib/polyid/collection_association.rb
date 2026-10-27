module PolyId
  # a loaded inverse_of association scans its records by id, never reaching Relation#find
  module CollectionAssociation
    def find(*args)
      return super unless options[:inverse_of] && loaded? && klass.polyid?

      super(*klass.polyid_translate_find_args(args))
    end
  end
end
