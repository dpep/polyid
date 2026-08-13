module PolyId
  module Cache
    class << self
      def read_multi(model_name, ids: [], uuids: [])
        id_keys = ids.to_h { |id| [id, id_key(model_name, id)] }
        uuid_keys = uuids.to_h { |uuid| [uuid, uuid_key(model_name, uuid)] }
        keys = id_keys.values + uuid_keys.values

        cached = PolyId.cache.read_multi(*keys)

        {
          ids: id_keys.each_with_object({}) do |(id, cache_key), values|
            values[id] = cached[cache_key] if cached.key?(cache_key)
          end,
          uuids: uuid_keys.each_with_object({}) do |(uuid, cache_key), values|
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
          {
            id_key(model_name, id) => uuid,
            uuid_key(model_name, uuid) => id,
          },
          expires_in: PolyId.cache_ttl,
        )
      end

      def delete_multi(model_name, ids: [], uuids: [])
        keys = ids.map { |id| id_key(model_name, id) } +
          uuids.map { |uuid| uuid_key(model_name, uuid) }

        PolyId.cache.delete_multi(keys)
      end

      private

      def id_key(model_name, id)
        "polyid/#{model_name}/#{id}"
      end

      def uuid_key(model_name, uuid)
        "polyid/#{model_name}/uuid:#{uuid}"
      end
    end
  end
end
