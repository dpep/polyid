###  Unreleased
- configuring auto_detect or default_uuid_attribute after models load now raises
  instead of silently doing nothing.  set them in an initializer
- uuid lookups via relations and associations
- require activerecord >= 7.2
- remove unused PolyId::Cache.read and PolyId::Cache.delete
- translation helpers raise on models not configured with polyid
- binary uuid columns cast invalid input to nil instead of raising
- binary uuid columns read correctly on postgres
- validate uuid format, rejecting invalid input instead of replacing it
- uuids are write-once, so legacy rows can be backfilled
- `save(validate: false)` and custom validation contexts still generate a uuid
- remove PolyId.cache_binary_uuids
- `dup` clears the uuid, so the copy gets its own
- add PolyId.cache_ttl, defaulting to 30 days.  set to nil to never expire
- translation is a real read-through cache, resolving misses in one bulk write
- loading records no longer writes to the cache.  lookups populate it instead,
  so an ordinary query no longer costs a cache write per row
- uppercase uuids resolve, on both string and binary columns
- STI subclasses share cached mappings with their base class
- uuids written in uppercase to a string column are stored lowercase, so
  lookups find them.  rows already stored in uppercase need a one-off downcase
- garbage cache values, including 0.2.0's packed binary uuids, are treated as
  misses and overwritten
- the cache is written after commit, so a rolled back record is never cached,
  including by a lookup made inside the transaction
- saving a record only writes the cache when it gains a uuid, not on every update
- `PolyId.is_uuid?` is renamed `PolyId.uuid?`.  `is_uuid?` remains as an alias
- `rake polyid:backfill` drops its `uuid_attribute` argument and always fills
  the model's polyid column: `rake "polyid:backfill[User,5000]"`
- uuid-shaped values that are not valid uuids no longer fall through to an
  integer id lookup
- `uuid_for` casts string ids, so `uuid_for(params[:id])` works on a cold cache
- uuid lookups ignore default scopes; the outer query still applies them
- strings with invalid bytes no longer raise from `where`
- `PolyId.reset` no longer clears the configured cache store
- saving or destroying a record loaded with a partial select no longer raises
  MissingAttributeError
- a binary `uuid` primary key is left alone rather than cast as a polyid uuid
- uuids are translated in table-qualified keys (`"users.id"`), foreign keys
  (`account_id:`), belongs_to associations (`account:`), and sets, and
  surrounding whitespace is ignored
- uuids are translated when a join is keyed by a table whose name differs from
  the association's
- `find` with an unknown uuid names it in the RecordNotFound message
- a uuid that resolves to nothing matches nothing in `where`, `find_by`,
  `exists?`, and `delete`, instead of falling through to an integer id
- `find(uuid)` works on a loaded `has_many ..., inverse_of:` association
- collection id writers like `user_ids=` accept uuids, instead of
  integer-casting them into unrelated ids
- a foreign key onto the uuid itself (`belongs_to primary_key: :uuid`) is left
  untranslated
- uuids in permitted params passed to `where`, `find_by`, or the
  `find_or_create_by` family are translated
- `find_or_create_by`, `create_or_find_by`, and `find_or_initialize_by` create
  with translated uuids, not just find with them.  a uuid that doesn't resolve
  raises RecordNotFound
- a database error during auto-detection no longer disables polyid for that
  model until restart
- backfill rejects invalid generated uuids and never overwrites one assigned
  while it runs
- backfill rejects a batch size that isn't a positive integer, rather than
  silently filling nothing

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
