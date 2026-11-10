module PolyId
  module Model
    extend ActiveSupport::Concern

    MEMOISED = %i[@polyid_uuid_attribute @polyid_types_registered].freeze
    # what an unresolved uuid translates to: a query matches nothing, a write refuses
    NO_MATCH = [].freeze

    # drops resolved config so global settings apply again -- supports PolyId.reset
    def self.reset_all! # :nodoc:
      return unless defined?(ActiveRecord::Base)

      ActiveRecord::Base.descendants.each do |model|
        MEMOISED.each do |ivar|
          model.remove_instance_variable(ivar) if model.instance_variable_defined?(ivar)
        end
      end
    end

    included do
      class_attribute :polyid_uuid_attribute_raw, :polyid_uuid_generator,
        instance_accessor: false, instance_predicate: false
      # written only by the `polyid` macro, which refuses once config is resolved
      private_class_method :polyid_uuid_attribute_raw=, :polyid_uuid_generator=

      before_validation :polyid_assign_uuid, on: :create
      before_validation :polyid_canonicalise_uuid
      # for save(validate: false) and custom contexts, which skip the above
      before_create :polyid_assign_uuid
      before_save :polyid_canonicalise_uuid
      validate :polyid_validate_uuid_format
      validate :polyid_validate_uuid_immutable
      # a rolled back id can be reused, so only cache what is committed
      after_commit :polyid_warm_cache, on: %i[create update]
      after_destroy :polyid_evict_cache
    end

    class_methods do
      def polyid(uuid_attribute: nil, uuid_generator: nil)
        if defined?(@polyid_uuid_attribute)
          raise PolyId::ConfigurationError,
            "#{name} has already resolved its polyid config; declare `polyid` in the class body"
        end
        PolyId.validate_uuid_generator!(uuid_generator)

        self.polyid_uuid_attribute_raw = (uuid_attribute || polyid_setting(:default_uuid_attribute)).to_s
        self.polyid_uuid_generator = uuid_generator
      end

      # must register before the schema builds its attribute set
      def load_schema
        polyid_register_types
        super
      end

      # `find` has a statement cache fast path that bypasses the relation
      def find(*ids)
        return super unless polyid?

        super(*polyid_translate_find_args(ids))
      end

      # `find_by` has a statement cache fast path that bypasses `where`
      def find_by(*args)
        return super unless args.length == 1 && args.first.is_a?(Hash)

        super(polyid_translate_conditions(args.first))
      end

      def id_for(value)
        ids_for([value]).first
      end

      def ids_for(values)
        polyid_required!
        values = Array(values)
        uuids = values.filter_map { |value| PolyId.normalize_uuid(value) }

        # unscoped: the mapping is global, and the caller's query still applies its scope
        resolved_uuids = PolyId::Cache.fetch_ids(
          polyid_cache_name, uuids:, defer: method(:polyid_after_commit),
        ) do |missing_uuids|
          unscoped.where(polyid_uuid_attribute => missing_uuids)
            .pluck(polyid_uuid_attribute, primary_key).to_h
        end

        values.map do |value|
          uuid = PolyId.normalize_uuid(value)
          uuid ? resolved_uuids[uuid] : value
        end
      end

      def uuid_for(value)
        uuids_for([value]).first
      end

      def uuids_for(values)
        polyid_required!
        # cast so "1" matches the integer key that pluck returns
        pk_type = type_for_attribute(primary_key)
        values = Array(values).map { |value| PolyId.normalize_uuid(value) || pk_type.cast(value) }
        ids = values.reject { |value| PolyId.normalize_uuid(value) || value.blank? }

        resolved_ids = PolyId::Cache.fetch_uuids(
          polyid_cache_name, ids:, defer: method(:polyid_after_commit),
        ) do |missing_ids|
          # a row with no uuid yet (or a junk one) has nothing worth caching
          unscoped.where(primary_key => missing_ids)
            .pluck(primary_key, polyid_uuid_attribute).to_h
            .select { |_id, uuid| PolyId.uuid?(uuid) }
        end

        values.map do |value|
          PolyId.normalize_uuid(value) ? value : resolved_ids[value]
        end
      end

      # .present? would regex-match the string
      def polyid?
        !polyid_uuid_attribute.nil?
      end

      # nested conditions are translated even when this model isn't polyid
      def polyid_translate_conditions(conditions) # :nodoc:
        translated = nil

        conditions.each do |key, values|
          new_values = polyid_translate_condition(key, values)
          next if new_values.nil? || new_values.equal?(values)

          translated ||= conditions.dup
          translated[key] = new_values
        end

        translated || conditions
      end

      # STI subclasses share a table, so they share cached mappings
      def polyid_cache_name # :nodoc:
        base_class.name
      end

      def polyid_uuid_attribute
        return @polyid_uuid_attribute if defined?(@polyid_uuid_attribute)

        @polyid_uuid_attribute =
          if polyid_uuid_attribute_raw.present?
            polyid_uuid_attribute_raw
          elsif polyid_auto_detection?
            polyid_setting(:default_uuid_attribute).to_s
          end
      rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
        # unmemoised, so a database blip doesn't disable polyid for good
        nil
      end

      def polyid_generate_uuid # :nodoc:
        PolyId.generate_uuid(polyid_uuid_generator || PolyId.uuid_generator)
      end

      # an unresolved uuid would reach ActiveRecord as nil, hiding it from the error
      def polyid_translate_find_args(args) # :nodoc:
        wrapped = args.length == 1 && args.first.is_a?(Array)
        # ActiveRecord flattens too, eg. find(1, [2, 3])
        values = args.flatten
        ids = ids_for(values)

        missing = values.zip(ids).find { |value, id| id.nil? && PolyId.normalize_uuid(value) }&.first
        if missing
          raise ActiveRecord::RecordNotFound.new(
            "Couldn't find #{name} with '#{primary_key}'=#{missing}", name, primary_key, missing,
          )
        end

        wrapped ? [ids] : ids
      end

      # rows read in a transaction may never commit.  a non-joinable transaction,
      # eg. transactional tests, commits each nested one's callbacks itself
      def polyid_after_commit(&) # :nodoc:
        transaction = with_connection(&:current_transaction)
        transaction.joinable? ? transaction.after_commit(&) : yield
      end

      # an unresolved uuid must match nothing, not fall through to an integer cast
      # or become a NULL that matches rows with no foreign key
      def polyid_translate_ids(values) # :nodoc:
        if polyid_collection?(values)
          return values if values.none? { |value| PolyId.normalize_uuid(value) }

          values = values.to_a
          ids = values.zip(ids_for(values)).reject { |value, id| id.nil? && PolyId.normalize_uuid(value) }.map(&:last)
          return ids.presence || NO_MATCH
        end

        PolyId.normalize_uuid(values) ? id_for(values) || NO_MATCH : values
      end

      # the model whose ids a column holds: this one for its primary key, or a
      # belongs_to target for a foreign key or association name
      def polyid_key_target(key) # :nodoc:
        # "users.id"
        table, column = key.to_s.split(".", 2)
        return (table == table_name ? self : polyid_associated_model(table))&.polyid_key_target(column) if column

        key.to_s == primary_key ? self : polyid_referenced_model(key)
      end

      private

      # an IN list, rather than a scalar
      def polyid_collection?(values)
        values.is_a?(Array) || values.is_a?(Set)
      end

      def polyid_translate_condition(key, values)
        return polyid_associated_model(key)&.polyid_translate_conditions(values) if values.is_a?(Hash)
        # tuple keys, eg. [:id, :name] => [[1, "a"]], as in_batches builds
        return if key.is_a?(Array)
        # checking the value first spares resolving association classes for every key
        return unless (polyid_collection?(values) ? values : [values]).any? { |value| PolyId.normalize_uuid(value) }

        # "users.id" => uuid
        table, column = key.to_s.split(".", 2)
        if column
          model = table == table_name ? self : polyid_associated_model(table)
          return model&.polyid_translate_conditions(column => values)&.fetch(column)
        end

        # stored lowercase, so query lowercase
        if polyid? && key.to_s == polyid_uuid_attribute
          return values.map { |value| PolyId.normalize_uuid(value) || value } if polyid_collection?(values)

          return PolyId.normalize_uuid(values)
        end

        model = polyid_key_target(key)
        model.polyid_translate_ids(values) if model&.polyid?
      end

      # the belongs_to target of an association name or foreign key
      def polyid_referenced_model(key)
        reflections = Array(reflect_on_association(key)).presence ||
          reflect_on_all_associations(:belongs_to).select { |assoc| assoc.foreign_key.to_s == key.to_s }

        reflections.each do |reflection|
          next unless reflection.belongs_to? && !reflection.polymorphic?
          # eg. primary_key: :uuid, where the foreign key already holds uuids
          next unless reflection.association_primary_key.to_s == reflection.klass.primary_key

          return reflection.klass
        rescue NameError
          # a class_name that doesn't load has nothing to translate
        end

        nil
      end

      def polyid_required!
        raise ArgumentError, "#{name} is not configured with polyid" unless polyid?
      end

      # mirrors ActiveRecord::TableMetadata#associated_table
      def polyid_associated_model(key)
        reflection = reflect_on_association(key) || reflect_on_association(key.to_s.singularize)
        return self if reflection.nil? && key.to_s == table_name
        return polyid_model_for_table(key) if reflection.nil?
        return if reflection.polymorphic?

        reflection.klass
      end

      # a join is keyed by table, which differs from the association name
      # given a class_name, eg. belongs_to :author, class_name: "User"
      def polyid_model_for_table(table)
        reflect_on_all_associations.reject(&:polymorphic?).each do |reflection|
          return reflection.klass if reflection.klass.table_name == table.to_s
        rescue NameError
          # a class_name that doesn't load has nothing to translate
        end

        nil
      end

      # a setting baked into models locks once read, so a late change raises
      # rather than going unseen
      def polyid_setting(name)
        PolyId.config_resolved!
        PolyId.public_send(name)
      end

      def polyid_auto_detection?
        return false unless polyid_setting(:auto_detect?)
        return false if abstract_class?
        return false unless respond_to?(:table_exists?) && table_exists?

        uuid_attribute = polyid_setting(:default_uuid_attribute).to_s
        primary_key.present? && primary_key != uuid_attribute && column_names.include?(uuid_attribute)
      end

      # decorators apply lazily, so these must not read the schema they decorate
      def polyid_register_types
        return if @polyid_types_registered

        @polyid_types_registered = true

        polyid_register_integer_guard
        polyid_register_uuid_type
      end

      # every integer column, since which ones polyid translates is only known
      # once the model and its associations resolve
      def polyid_register_integer_guard
        decorate_attributes do |name, type|
          type.dup.extend(PolyId::IntegerGuard).polyid_guard(self, name) if type.type == :integer
        end
      end

      def polyid_register_uuid_type
        uuid_attribute = polyid_uuid_attribute_raw.presence ||
          (polyid_setting(:default_uuid_attribute).to_s if polyid_setting(:auto_detect?))
        return unless uuid_attribute
        # auto-detection skips a uuid primary key, so its bytes aren't polyid's to judge
        return if polyid_uuid_attribute_raw.blank? && primary_key == uuid_attribute

        decorate_attributes([uuid_attribute]) do |_name, subtype|
          PolyId::BinaryUuidType.new(subtype) if subtype.type == :binary
        end
      end
    end

    # a copy is a new row, so it needs its own uuid.  reset as dup resets the
    # primary key; not via init_attributes, which activerecord 7.2 lacks
    def initialize_dup(other)
      super
      @attributes.reset(self.class.polyid_uuid_attribute) if self.class.polyid?
    end

    private

    # false after a partial select, eg. select(:id), where reading it would raise
    def polyid_uuid_loaded?
      self.class.polyid? && has_attribute?(self.class.polyid_uuid_attribute)
    end

    def polyid_assign_uuid
      return unless self.class.polyid?

      uuid_attribute = self.class.polyid_uuid_attribute
      return if public_send(uuid_attribute).present?
      # invalid input casts to nil -- let the format validation report it
      return if read_attribute_before_type_cast(uuid_attribute).present?

      public_send("#{uuid_attribute}=", self.class.polyid_generate_uuid)
    end

    # lookups downcase, so a string column must store lowercase to be found
    def polyid_canonicalise_uuid
      return unless polyid_uuid_loaded?

      uuid_attribute = self.class.polyid_uuid_attribute
      value = public_send(uuid_attribute)
      return unless PolyId.uuid?(value) && value != value.downcase
      return unless new_record? || will_save_change_to_attribute?(uuid_attribute)

      public_send("#{uuid_attribute}=", value.downcase)
    end

    # a uuid is write-once, so only a create or a backfill has anything to cache
    def polyid_warm_cache
      return unless self.class.polyid?
      return unless saved_change_to_attribute?(self.class.polyid_uuid_attribute)

      cache_polyid
    end

    # queued on the transaction, not a record after_commit: those run first, so a
    # lookup's deferred write made earlier in the transaction would land after it
    def polyid_evict_cache
      return unless self.class.polyid?

      id = public_send(self.class.primary_key)
      uuid = public_send(self.class.polyid_uuid_attribute) if polyid_uuid_loaded?

      self.class.polyid_after_commit do
        PolyId::Cache.delete_multi(
          self.class.polyid_cache_name,
          ids: id.present? ? [id] : [],
          uuids: uuid.present? ? [uuid] : [],
        )
      end
    end

    # a binary column casts bad input to nil, a string column keeps it verbatim
    def polyid_validate_uuid_format
      return unless polyid_uuid_loaded?

      uuid_attribute = self.class.polyid_uuid_attribute
      value = public_send(uuid_attribute)

      if value.present?
        # only judge a value being written, so legacy rows can be saved as-is
        return unless new_record? || will_save_change_to_attribute?(uuid_attribute)

        errors.add(uuid_attribute, "is invalid") unless PolyId.uuid?(value)
      elsif read_attribute_before_type_cast(uuid_attribute).present?
        # supplied, but failed to cast
        errors.add(uuid_attribute, "is invalid")
      end
    end

    # write-once, not read-only: a row predating polyid still needs backfilling
    def polyid_validate_uuid_immutable
      return unless polyid_uuid_loaded?

      uuid_attribute = self.class.polyid_uuid_attribute
      return unless persisted?
      return unless will_save_change_to_attribute?(uuid_attribute)
      return if attribute_in_database(uuid_attribute).nil?

      errors.add(uuid_attribute, "is immutable")
    end

    def cache_polyid
      id = public_send(self.class.primary_key)
      uuid = public_send(self.class.polyid_uuid_attribute)
      return if id.blank? || uuid.blank?

      PolyId::Cache.write(self.class.polyid_cache_name, id:, uuid:)
    end
  end
end
