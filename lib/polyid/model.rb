module PolyId
  module Model
    extend ActiveSupport::Concern

    # drops every model's resolved config, so global settings apply again.
    # supports PolyId.reset; not meant for production use.
    def self.reset_all!
      return unless defined?(ActiveRecord::Base)

      ActiveRecord::Base.descendants.each do |model|
        model.send(:polyid_reset!)
      end
    end

    included do
      class_attribute :polyid_uuid_attribute_raw, instance_writer: false
      class_attribute :polyid_uuid_generator, instance_writer: false

      before_validation :polyid_assign_uuid, on: :create
      validate :polyid_validate_uuid_format
      validate :polyid_validate_uuid_immutable
      after_save :polyid_warm_cache
      after_destroy :polyid_evict_cache
    end

    class_methods do
      def polyid(uuid_attribute: PolyId.default_uuid_attribute, uuid_generator: nil)
        if defined?(@polyid_uuid_attribute)
          raise PolyId::ConfigurationError,
            "#{name} has already resolved its polyid config; declare `polyid` in the class body"
        end

        self.polyid_uuid_attribute_raw = uuid_attribute.to_s
        self.polyid_uuid_generator = uuid_generator
      end

      # register before the schema builds its attribute set, so the decorator
      # is applied while the column types are being resolved
      def load_schema
        polyid_register_uuid_type
        super
      end

      def find(*ids)
        return super unless polyid?

        if ids.length == 1 && ids.first.is_a?(Array)
          super(ids_for(ids.first))
        else
          super(*ids_for(ids))
        end
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
        uuids = values.filter_map { |value| polyid_normalize_uuid(value) }

        resolved_uuids = PolyId::Cache.fetch_ids(polyid_cache_name, uuids: uuids) do |missing_uuids|
          where(polyid_uuid_attribute => missing_uuids)
            .pluck(polyid_uuid_attribute, primary_key).to_h
        end

        values.map do |value|
          uuid = polyid_normalize_uuid(value)
          uuid ? resolved_uuids[uuid] : value
        end
      end

      def uuid_for(value)
        uuids_for([value]).first
      end

      def uuids_for(values)
        polyid_required!
        values = Array(values)
        ids = values.reject { |value| PolyId.is_uuid?(value) || value.blank? }

        resolved_ids = PolyId::Cache.fetch_uuids(polyid_cache_name, ids: ids) do |missing_ids|
          where(primary_key => missing_ids)
            .pluck(primary_key, polyid_uuid_attribute).to_h
        end

        values.map do |value|
          PolyId.is_uuid?(value) ? value : resolved_ids[value]
        end
      end

      def polyid?
        polyid_uuid_attribute.present?
      end

      # translates UUIDs into ids, eg. `id: uuid` and `users: { id: uuid }`.
      # nested conditions are translated even when this model isn't polyid.
      def polyid_translate_conditions(conditions)
        translated = nil
        pk = primary_key if polyid?

        conditions.each do |key, values|
          new_values =
            if values.is_a?(Hash)
              polyid_associated_model(key)&.polyid_translate_conditions(values)
            elsif pk && key.to_s == pk
              polyid_translate_ids(values)
            end
          next if new_values.nil? || new_values.equal?(values)

          translated ||= conditions.dup
          translated[key] = new_values
        end

        translated || conditions
      end

      # STI subclasses share a table, so they share cached mappings
      def polyid_cache_name
        base_class.name
      end

      private

      def polyid_reset!
        remove_instance_variable(:@polyid_uuid_attribute) if defined?(@polyid_uuid_attribute)
        remove_instance_variable(:@polyid_uuid_type_registered) if defined?(@polyid_uuid_type_registered)
      end

      # uuids are case insensitive; canonicalise so lookups match what is stored
      def polyid_normalize_uuid(value)
        value.downcase if PolyId.is_uuid?(value)
      end

      def polyid_required!
        raise ArgumentError, "#{name} is not configured with polyid" unless polyid?
      end

      def polyid_translate_ids(values)
        is_array = values.is_a?(Array)
        return values unless is_array ? values.any? { |value| PolyId.is_uuid?(value) } : PolyId.is_uuid?(values)

        ids = ids_for(values)
        is_array ? ids : ids.first
      end

      # mirrors ActiveRecord::TableMetadata#associated_table
      def polyid_associated_model(key)
        reflection = reflect_on_association(key) || reflect_on_association(key.to_s.singularize)
        return self if reflection.nil? && key.to_s == table_name
        return if reflection.nil? || reflection.polymorphic?

        reflection.klass
      end

      def polyid_generate_uuid
        PolyId.generate_uuid(polyid_uuid_generator || PolyId.uuid_generator)
      end

      def polyid_uuid_attribute
        return @polyid_uuid_attribute if defined?(@polyid_uuid_attribute)

        # from here on, global config is baked into this model
        PolyId.config_resolved!

        @polyid_uuid_attribute =
          if polyid_uuid_attribute_raw.present?
            polyid_uuid_attribute_raw
          elsif polyid_auto_detection?
            PolyId.default_uuid_attribute.to_s
          end
      end

      def polyid_auto_detection?
        return false unless PolyId.auto_detect?
        return false if abstract_class?
        return false unless respond_to?(:table_exists?) && table_exists?

        uuid_attribute = PolyId.default_uuid_attribute.to_s
        primary_key.present? && primary_key != uuid_attribute && column_names.include?(uuid_attribute)
      rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
        false
      end

      # binary UUID support.  the configured attribute name is known without the
      # schema, and `decorate_attributes` resolves the column type lazily, so
      # this never reads the schema it is about to load.
      def polyid_register_uuid_type
        return if @polyid_uuid_type_registered
        @polyid_uuid_type_registered = true

        uuid_attribute = polyid_uuid_attribute_raw.presence ||
          (PolyId.default_uuid_attribute.to_s if PolyId.auto_detect?)
        return unless uuid_attribute

        decorate_attributes([ uuid_attribute ]) do |_name, subtype|
          PolyId::BinaryUuidType.new if subtype.type == :binary
        end
      end
    end

    private

    def polyid_assign_uuid
      return unless self.class.polyid?

      uuid_attribute = self.class.send(:polyid_uuid_attribute)
      return if public_send(uuid_attribute).present?
      # invalid input casts to nil -- leave it for the format validation to
      # report, rather than papering over it with a generated uuid
      return if read_attribute_before_type_cast(uuid_attribute).present?

      public_send("#{uuid_attribute}=", self.class.send(:polyid_generate_uuid))
    end

    def polyid_warm_cache
      return unless self.class.polyid?

      cache_polyid
    end

    def polyid_evict_cache
      return unless self.class.polyid?

      id = public_send(self.class.primary_key)
      uuid = public_send(self.class.send(:polyid_uuid_attribute))

      PolyId::Cache.delete_multi(
        self.class.polyid_cache_name,
        ids: id.present? ? [id] : [],
        uuids: uuid.present? ? [uuid] : [],
      )
    end

    # a binary column casts bad input to nil, a string column keeps it verbatim
    def polyid_validate_uuid_format
      return unless self.class.polyid?

      uuid_attribute = self.class.send(:polyid_uuid_attribute)
      value = public_send(uuid_attribute)

      if value.present?
        # only judge a value being written, so legacy rows can be saved as-is
        return unless new_record? || will_save_change_to_attribute?(uuid_attribute)

        errors.add(uuid_attribute, "is invalid") unless PolyId.is_uuid?(value)
      elsif read_attribute_before_type_cast(uuid_attribute).present?
        # supplied, but failed to cast
        errors.add(uuid_attribute, "is invalid")
      end
    end

    # write-once, not read-only: a row predating polyid still needs backfilling
    def polyid_validate_uuid_immutable
      return unless self.class.polyid?

      uuid_attribute = self.class.send(:polyid_uuid_attribute)
      return unless persisted?
      return unless will_save_change_to_attribute?(uuid_attribute)
      return if attribute_in_database(uuid_attribute).nil?

      errors.add(uuid_attribute, "is immutable")
    end

    def cache_polyid
      id = public_send(self.class.primary_key)
      uuid = public_send(self.class.send(:polyid_uuid_attribute))
      return if id.blank? || uuid.blank?

      PolyId::Cache.write(self.class.polyid_cache_name, id: id, uuid: uuid)
    end
  end
end
