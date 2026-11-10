PolyId
======
![Gem](https://img.shields.io/gem/dt/polyid?style=plastic)
[![codecov](https://codecov.io/gh/dpep/polyid/branch/main/graph/badge.svg)](https://codecov.io/gh/dpep/polyid)

`polyid` adds an ActiveRecord integration for models that keep both an
auto-incrementing primary key and a UUID column. Look records up by either one;
`id <=> uuid` translations are cached for reuse.

## Install


```ruby
gem "polyid"
```

Add a UUID column with a unique index. Lookups query it directly, so without one
every translation is a full table scan, and duplicate UUIDs resolve arbitrarily.

```ruby
add_column :users, :uuid, :string
add_index :users, :uuid, unique: true
```

That's it. Models with a `uuid` column are detected automatically, and new
records get a UUID on create. Read the [global footprint](#global-footprint)
before shipping, and if the table already has rows, see
[rolling out](#rolling-out-to-an-existing-table).

## Usage

```ruby
user = User.create!

User.find(user.id)
User.find(user.uuid)
User.find(user.id, user.uuid)
User.find([user.uuid, user.id])
```

UUIDs also work in hash conditions on the primary key, including through
associations and `belongs_to` foreign keys:

```ruby
User.where(id: user.uuid)
User.find_by(id: user.uuid)
User.where.not(id: user.uuid)
User.where("users.id" => user.uuid)

account.users.find(user.uuid)
account.users.where(id: user.uuid)

# User belongs_to :account, and Account is polyid
User.where(account_id: account.uuid)
User.where(account: account.uuid)
```

Scopes are still enforced, so `account.users.find(uuid)` raises
`ActiveRecord::RecordNotFound` for a user belonging to another account.

SQL strings are left alone: `where("id = ?", uuid)` is not translated.

Writes are translated by the `find_or_create_by` family and by collection id
writers like `user_ids=`, but not elsewhere. A UUID that reaches a polyid key
untranslated raises `PolyId::UntranslatedUuidError` rather than being cast to an
unrelated integer id, so pass ids there:

```ruby
User.create!(account_id: account.uuid)          # PolyId::UntranslatedUuidError
User.create!(account_id: account.id)            # ok
User.update_all(account_id: account.id)         # likewise create_with, insert_all
```

To translate without loading a record:

```ruby
User.id_for(user.uuid)                  # => 123
User.uuid_for(user.id)                  # => "8f47a7ca-8f4a-4d7b-96e6-60a0b47ddf68"

User.ids_for([user.uuid, 456, nil])     # => [123, 456, nil]
User.uuids_for([user.id, user.uuid])    # => ["8f47...", "8f47..."]
```

The plural forms preserve input order. A value already in the target form passes
through unchecked, and one that doesn't resolve comes back `nil`.

## UUID columns

### Binary storage

A UUID can be stored as 16 raw bytes, less than half the size of the 36 character
string:

```ruby
add_column :accounts, :uuid, :binary, limit: 16
add_index :accounts, :uuid, unique: true
```

PolyId notices the column type and converts, so you keep passing and reading
ordinary dashed strings.

### Rolling out to an existing table

Add the column as nullable, as above. New records get a UUID automatically.
Backfill existing rows with the rake task, which writes in batches and skips
validations and callbacks:

```sh
rake "polyid:backfill[Model,batch_size]"   # batch_size defaults to 1000
rake "polyid:backfill[User,5000]"
```

Once every row has one, enforce it:

```ruby
change_column_null :users, :uuid, false
```

### Validation

UUIDs are write-once. A row with none can be given one, so a half-migrated table
keeps working, but once set, validation rejects any change. Values that aren't
UUIDs are rejected rather than quietly replaced.

```ruby
user.update!(uuid: SecureRandom.uuid)   # ok when the column was NULL
user.update!(uuid: SecureRandom.uuid)   # ActiveRecord::RecordInvalid, immutable

User.create!(uuid: "nope")              # ActiveRecord::RecordInvalid, invalid
```

## Configuration

### UUID column

The default is `uuid`. Change it per model, or change the name auto-detection
looks for:

```ruby
class Account < ApplicationRecord
  polyid uuid_attribute: :public_id
end

PolyId.default_uuid_attribute = :public_id
```

### UUID generation

The default is v7, which is time-ordered and keeps inserts near the end of the
index rather than scattered across it. Override globally or per model:

```ruby
PolyId.uuid_generator = :v4
PolyId.uuid_generator = -> { MyIdService.next }

class Account < ApplicationRecord
  polyid uuid_generator: :v4
end
```

### Auto-detection

PolyId enables itself on any model with a `uuid` column, unless that column is
the primary key. To opt models in explicitly instead:

```ruby
PolyId.auto_detect = false

class User < ApplicationRecord
  polyid
end
```

### When to set these

`auto_detect` and `default_uuid_attribute` are baked into each model as it
resolves, so set them in an initializer. Setting them after a model has resolved
raises `PolyId::ConfigurationError`. `cache`, `cache_ttl`, and `uuid_generator`
are read on every use and can change at any time.

## Global footprint

PolyId hooks into every model, not only polyid ones. It adds validation, commit,
and destroy callbacks, and wraps `find`, `find_by`, `where`, and the
`find_or_create_by` family to translate UUIDs. On a model that isn't polyid, the
callbacks and `find` return early, but they are in the chain. `where` and
`find_by` still inspect hash conditions, since those can reference a polyid
model through an association.

With auto-detection on, every model with a `uuid` column becomes polyid,
including tables that had one before you installed the gem. New rows get a
generated value, and the column is held to the format and write-once rules
above.

## Caching

PolyId caches translations in memory, per process, by default. Lookups populate
the cache as they resolve, and committing a new UUID caches its mapping. Loading
records does not, so an ordinary query costs nothing extra.

Use a shared store such as Redis or `Rails.cache` so processes share translations
and evictions:

```ruby
# config/environments/production.rb
config.cache_store = :redis_cache_store, {
  url: ENV.fetch("REDIS_URL"),
}

# config/initializers/polyid.rb
PolyId.cache = Rails.cache
```

### Cache contract

Mappings are evicted when a record is destroyed. `delete_all`, `update_all`, and
raw SQL skip callbacks, so they leave entries behind. That's harmless while ids
are never reused: a stale entry just resolves to a missing row. If ids can be
reused (a sequence reset, a restore, manually assigned ids), clear the cache
afterwards or a stale UUID can resolve to an unrelated record.

### Expiry

Entries expire after 30 days by default. A mapping never changes, so expiry only
costs a re-query.

```ruby
PolyId.cache_ttl = 1.week
PolyId.cache_ttl = nil    # never expire
```

Leave the TTL set unless your Redis uses an `allkeys-*` policy. `volatile-*`
policies only evict keys that have a TTL, so entries without one are never
reclaimed and crowd out keys that can be. Under `noeviction`, Redis's default, a
full instance refuses writes instead of making room.

----
## Contributing

Yes please  :)

1. Fork it
1. Create your feature branch (`git checkout -b my-feature`)
1. Ensure the tests pass (`bundle exec rspec`)
1. Commit your changes (`git commit -am 'awesome new feature'`)
1. Push your branch (`git push origin my-feature`)
1. Create a Pull Request
