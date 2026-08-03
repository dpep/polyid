###  Unreleased
- uuid lookups via relations and associations
- require activerecord >= 7.2
- remove unused PolyId::Cache.read and PolyId::Cache.delete
- translation helpers raise on models not configured with polyid
- binary uuid columns cast invalid input to nil instead of raising

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
