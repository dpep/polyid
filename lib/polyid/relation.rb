module PolyId
  # Extends relations and associations to accept UUIDs wherever the primary key
  # is expected, eg. `account.users.find(uuid)` and `User.where(id: uuid)`.
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

    # `where`, `where.not`, `rewhere`, and friends all funnel through here, so
    # this is the one place UUID conditions need translating.  Public to match
    # ActiveRecord, which calls it with an explicit receiver.
    def build_where_clause(opts, rest = [])
      return super unless opts.is_a?(Hash)

      super(klass.polyid_translate_conditions(opts), rest)
    end
  end
end
