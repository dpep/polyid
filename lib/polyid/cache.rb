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

      # the block resolves whatever is missing, and what it resolves is cached
      def fetch_ids(model_name, uuids:)
        cached_ids = read_multi(model_name, uuids: uuids)[:uuids]
        missing_uuids = uuids - cached_ids.keys
        return cached_ids if missing_uuids.empty?

        resolved = yield(missing_uuids) # uuid => id
        write_multi(model_name, resolved.invert)

        cached_ids.merge(resolved)
      end

      def fetch_uuids(model_name, ids:)
        cached_uuids = read_multi(model_name, ids: ids)[:ids]
        missing_ids = ids - cached_uuids.keys
        return cached_uuids if missing_ids.empty?

        resolved = yield(missing_ids) # id => uuid
        write_multi(model_name, resolved)

        cached_uuids.merge(resolved)
      end

      def write(model_name, id:, uuid:)
        write_multi(model_name, id => uuid)
      end

      def write_multi(model_name, mappings)
        return if mappings.empty?

        entries = mappings.each_with_object({}) do |(id, uuid), keys|
          keys[id_key(model_name, id)] = uuid
          keys[uuid_key(model_name, uuid)] = id
        end

        PolyId.cache.write_multi(entries, expires_in: PolyId.cache_ttl)
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
