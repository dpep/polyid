###  Unreleased
- uuid lookups via relations and associations
- require activerecord >= 7.2
- remove unused PolyId::Cache.read and PolyId::Cache.delete
- translation helpers raise on models not configured with polyid
- binary uuid columns cast invalid input to nil instead of raising
- validate uuid format, rejecting invalid input instead of replacing it
- uuids are write-once, so legacy rows can be backfilled
- remove PolyId.cache_binary_uuids
- add PolyId.cache_ttl, defaulting to 30 days.  set to nil to never expire
- translation is a real read-through cache, resolving misses in one bulk write
- loading records no longer writes to the cache.  lookups populate it instead,
  so an ordinary query no longer costs a cache write per row

###  0.2.0  (2026-04-26)
- casting upgrade
- is_uuid upgrade
- binary uuid support
- rspec-uuid
- migration helpers
- make uuid column immutable
- binary encode uuids

###  0.1.0  (2026-04-10)
- initial build
