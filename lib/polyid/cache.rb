module PolyId
  module Cache
    class << self
      def read(model_name, id: nil, uuid: nil)
        PolyId.cache.read(key(model_name, id: id, uuid: uuid))
      end

      def read_multi(model_name, ids: [], uuids: [])
        keys = ids.map { |id| key(model_name, id: id) } +
          uuids.map { |uuid| key(model_name, uuid: uuid) }

        cached = PolyId.cache.read_multi(*keys)

        {
          ids: ids.each_with_object({}) do |id, values|
            cache_key = key(model_name, id: id)
            values[id] = cached[cache_key] if cached.key?(cache_key)
          end,
          uuids: uuids.each_with_object({}) do |uuid, values|
            cache_key = key(model_name, uuid: uuid)
            values[uuid] = cached[cache_key] if cached.key?(cache_key)
          end,
        }
      end

      def fetch_ids(model_name, uuids:)
        cached_ids = read_multi(model_name, uuids: uuids)[:uuids]
        missing_uuids = uuids - cached_ids.keys

        if missing_uuids.any?
          yielded_ids = yield(missing_uuids)
          cached_ids.merge!(yielded_ids)
        end

        cached_ids
      end

      def fetch_uuids(model_name, ids:)
        cached_uuids = read_multi(model_name, ids: ids)[:ids]
        missing_ids = ids - cached_uuids.keys

        if missing_ids.any?
          yielded_uuids = yield(missing_ids)
          cached_uuids.merge!(yielded_uuids)
        end

        cached_uuids
      end

      def write(model_name, id:, uuid:)
        PolyId.cache.write_multi(
          key(model_name, id: id) => uuid,
          key(model_name, uuid: uuid) => id,
        )
      end

      def delete(model_name, id:, uuid:)
        delete_multi(model_name, ids: [id], uuids: [uuid])
      end

      def delete_multi(model_name, ids: [], uuids: [])
        keys = ids.map { |id| key(model_name, id: id) } +
          uuids.map { |uuid| key(model_name, uuid: uuid) }

        PolyId.cache.delete_multi(keys)
      end

      private

      def key(model_name, id: nil, uuid: nil)
        raise ArgumentError, "id or uuid required" if id.nil? && uuid.nil?

        locator = id.nil? ? "uuid:#{uuid}" : "id:#{id}"
        "polyid/#{model_name}/#{locator}"
      end
    end
  end
end
