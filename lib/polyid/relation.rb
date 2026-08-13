module PolyId
  # accept UUIDs wherever the primary key is expected
  module Relation
    def find(*ids)
      return super if block_given?
      return super unless klass.polyid?

      if ids.length == 1 && ids.first.is_a?(Array)
        super(klass.ids_for(ids.first))
      else
        super(*klass.ids_for(ids))
      end
    end

    # `where`, `where.not`, and `rewhere` all funnel through here.
    # public to match ActiveRecord, which calls it with an explicit receiver.
    def build_where_clause(opts, rest = [])
      return super unless opts.is_a?(Hash)

      super(klass.polyid_translate_conditions(opts), rest)
    end
  end
end
