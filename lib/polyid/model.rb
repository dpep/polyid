module PolyId
  module Model
    extend ActiveSupport::Concern

    included do
      class_attribute :polyid_uuid_attribute, instance_writer: false
      class_attribute :polyid_uuid_generator, instance_writer: false

      before_validation :polyid_assign_uuid, on: :create
      validate :polyid_validate_uuid_immutable
      after_find :polyid_warm_cache
      after_save :polyid_warm_cache
      after_destroy :polyid_evict_cache
    end

    class_methods do
      def polyid(uuid_attribute: :uuid, uuid_generator: nil)
        self.polyid_uuid_attribute = uuid_attribute.to_s
        self.polyid_uuid_generator = uuid_generator
        attribute(polyid_uuid_attribute, polyid_uuid_type) if polyid_binary_uuid?
      end

      def find(*ids)
        return super unless polyid?

        if ids.length == 1 && ids.first.is_a?(Array)
          # find([1, 2])
          super(resolve_polyids(ids.first))
        else
          # find(1) or find(1, 2)
          super(*resolve_polyids(ids))
        end
      end

      def id_for(value)
        ids_for([value]).first
      end

      def ids_for(values)
        values = Array(values)
        uuids = values.select { |value| PolyId.is_uuid?(value) }

        resolved_uuids = PolyId::Cache.fetch_ids(name, uuids: uuids) do |missing_uuids|
          where(polyid_uuid_attribute => missing_uuids).each_with_object({}) do |record, resolved|
            resolved[record.public_send(polyid_uuid_attribute)] = record.public_send(primary_key)
          end
        end

        values.map do |value|
          if PolyId.is_uuid?(value)
            resolved_uuids[value]
          else
            value
          end
        end
      end

      def uuid_for(value)
        uuids_for([value]).first
      end

      def uuids_for(values)
        values = Array(values)
        ids = values.reject { |value| PolyId.is_uuid?(value) || value.blank? }

        resolved_ids = PolyId::Cache.fetch_uuids(name, ids: ids) do |missing_ids|
          where(primary_key => missing_ids).each_with_object({}) do |record, resolved|
            resolved[record.public_send(primary_key)] = record.public_send(polyid_uuid_attribute)
          end
        end

        values.map do |value|
          if PolyId.is_uuid?(value)
            value
          else
            resolved_ids[value]
          end
        end
      end

      def polyid?
        polyid_uuid_attribute.present?
      end

      private

      def polyid_generate_uuid
        PolyId.generate_uuid(polyid_uuid_generator || PolyId.uuid_generator)
      end

      def polyid_binary_uuid?
        columns_hash[polyid_uuid_attribute]&.type == :binary
      end

      def polyid_uuid_type
        @polyid_uuid_type ||= PolyId::BinaryUuidType.new
      end

      def resolve_polyids(values)
        uuids = values.select { |value| PolyId.is_uuid?(value) }
        cached_ids = PolyId::Cache.fetch_ids(name, uuids: uuids) do |missing_uuids|
          where(polyid_uuid_attribute => missing_uuids).each_with_object({}) do |record, ids|
            ids[record.public_send(polyid_uuid_attribute)] = record.public_send(primary_key)
          end
        end

        values.map do |value|
          PolyId.is_uuid?(value) ? cached_ids[value] : value
        end
      end
    end

    private

    def polyid_assign_uuid
      return unless self.class.polyid?
      return if public_send(self.class.polyid_uuid_attribute).present?

      public_send("#{self.class.polyid_uuid_attribute}=", self.class.send(:polyid_generate_uuid))
    end

    def polyid_warm_cache
      return unless self.class.polyid?

      cache_polyid
    end

    def polyid_evict_cache
      return unless self.class.polyid?

      id = public_send(self.class.primary_key)
      uuid = public_send(self.class.polyid_uuid_attribute)

      PolyId::Cache.delete_multi(
        self.class.name,
        ids: id.present? ? [id] : [],
        uuids: uuid.present? ? [uuid] : [],
      )
    end

    def polyid_validate_uuid_immutable
      return unless persisted?
      return unless will_save_change_to_attribute?(self.class.polyid_uuid_attribute)

      errors.add(self.class.polyid_uuid_attribute, "is immutable")
    end

    def cache_polyid
      id = public_send(self.class.primary_key)
      uuid = public_send(self.class.polyid_uuid_attribute)
      return if id.blank? || uuid.blank?

      PolyId::Cache.write(self.class.name, id: id, uuid: uuid)
    end
  end
end
