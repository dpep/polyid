###  Unreleased

#### Upgrading from 0.2.0
- requires activerecord >= 7.2, now a runtime dependency
- set `auto_detect` and `default_uuid_attribute` in an initializer, and declare
  `polyid` in the class body.  changing either setting, or calling `polyid`,
  after a model has resolved raises PolyId::ConfigurationError rather than
  silently doing nothing
- delete any `PolyId.cache_binary_uuids =` line.  the setting is gone
- `rake polyid:backfill` drops its `uuid_attribute` argument and always fills
  the model's polyid column: `rake "polyid:backfill[User,5000]"`.  the old
  three-argument form fails, since the column name lands in `batch_size`
- downcase any uuids already stored in uppercase in a string column.  uuids are
  now written lowercase, and lookups, including `where(uuid: ...)`, query
  lowercase
- pass ids, not uuids, on write paths polyid doesn't translate, such as
  `create!(account_id: uuid)`, `create_with`, `update_all`, and `insert_all`.
  a uuid there raises PolyId::UntranslatedUuidError instead of being
  integer-cast into an unrelated id
- optionally, clear `polyid/*` cache keys once.  0.2.0 wrote them with no
  expiry, so a Redis `volatile-*` policy never evicts them

#### Added
- uuids work in hash conditions: `where`, `where.not`, `rewhere`, `find_by`,
  `exists?`, and `delete`, on the primary key and on `belongs_to` foreign keys
  and association names, including table-qualified keys, joined tables, sets,
  and permitted params.  a uuid that resolves to nothing matches nothing
- `find(uuid)` works through relations and associations, including a loaded
  `has_many ..., inverse_of:` association
- the `find_or_create_by` family and collection id writers like `user_ids=`
  accept uuids.  one that resolves to nothing raises RecordNotFound naming the
  missing record
- `PolyId.cache_ttl`, defaulting to 30 days.  set to nil to never expire
- `polyid?` and `polyid_uuid_attribute` are documented for introspection.  the
  public API is what the README documents

#### Changed
- invalid uuids are rejected by validation rather than replaced, and a uuid is
  write-once rather than immutable, so a row that predates polyid can be
  backfilled
- binary uuid columns cast invalid input to nil instead of raising
- the translation helpers raise on models not configured with polyid
- lookups populate the cache, resolving misses in one bulk write, and
  committing a new uuid caches it.  loading records no longer writes to the
  cache, and saving only does when a record gains a uuid
- `PolyId.is_uuid?` is renamed `PolyId.uuid?`.  `is_uuid?` remains as an alias
- an unsupported uuid generator raises when it's configured, by
  `PolyId.uuid_generator=` or `polyid uuid_generator:`, not on the first save
- `polyid_uuid_attribute_raw` and `polyid_uuid_generator` are no longer defined
  on every model instance, and their class writers are private
- `PolyId.reset` no longer clears the configured cache store
- remove unused `PolyId::Cache.read` and `PolyId::Cache.delete`

#### Fixed
- a uuid never falls through to an integer id lookup, including a uuid-shaped
  value that isn't a valid RFC uuid
- `find` with an unknown uuid names it in the RecordNotFound message
- uppercase and whitespace-padded uuids resolve, on string and binary columns
- `find` and the translation helpers no longer raise on strings with invalid
  bytes
- `uuid_for` casts string ids, so `uuid_for(params[:id])` works on a cold cache
- uuid lookups find rows hidden by a default scope; the outer query still
  applies it
- binary uuid columns read correctly on postgres
- `save(validate: false)` and custom validation contexts still generate a uuid
- `dup` clears the uuid, so the copy gets its own
- saving or destroying a record loaded with a partial select no longer raises
  MissingAttributeError
- STI subclasses share cached mappings with their base class
- the cache is written after commit, so a rolled back record is never cached,
  including by a lookup made inside the transaction
- garbage cache values, including 0.2.0's packed binary uuids, are treated as
  misses and overwritten
- a database error during auto-detection no longer disables polyid for that
  model until restart
- backfill rejects invalid generated uuids and a batch size that isn't a
  positive integer, and never overwrites a uuid assigned while it runs

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
