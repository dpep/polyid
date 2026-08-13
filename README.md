PolyId
======
![Gem](https://img.shields.io/gem/dt/polyid?style=plastic)
[![codecov](https://codecov.io/gh/dpep/polyid/branch/main/graph/badge.svg)](https://codecov.io/gh/dpep/polyid)

`polyid` adds an ActiveRecord integration for models that keep both an
auto-incrementing primary key and a UUID column. It lets you look records up by
either identifier and caches `id <=> uuid` translations for reuse.

## Usage

```ruby
require "polyid"

class User < ApplicationRecord
  # optional when your model has both `id` and `uuid` columns
  polyid
end

user = User.create!(uuid: SecureRandom.uuid)

User.find(user.id)
User.find(user.uuid)

User.id_for(user.uuid)
User.uuid_for(user.id)

User.ids_for([user.uuid, 123, nil])
User.uuids_for([user.id, "8f47a7ca-8f4a-4d7b-96e6-60a0b47ddf68", nil])
```

`find` accepts IDs, UUIDs, or a mix of both:

```ruby
User.find(user.id)
User.find(user.uuid)
User.find(user.id, user.uuid)
User.find([user.uuid, user.id])
```

UUIDs work anywhere the primary key is expected, including through relations and
associations:

```ruby
User.where(id: user.uuid)
User.find_by(id: user.uuid)
User.where.not(id: user.uuid)

account.users.find(user.uuid)
account.users.where(id: user.uuid)
```

Scopes are still enforced, so `account.users.find(uuid)` raises
`ActiveRecord::RecordNotFound` for a user belonging to another account.

Translation helpers preserve input order and return `nil` for misses:

```ruby
User.id_for(user.uuid)       # => 123
User.uuid_for(user.id)       # => "..."
```

By default `polyid` uses the `uuid` column. You can point it at another column:

```ruby
class Account < ApplicationRecord
  polyid uuid_attribute: :public_id
end
```

### Auto-detection

By default, PolyId automatically enables translation helpers for models that
have both `id` and `uuid` columns. If you prefer explicit model opt-in, disable
auto-detection:

```ruby
PolyId.auto_detect = false
```

You can also change which UUID column name auto-detection checks:

```ruby
PolyId.default_uuid_attribute = :public_id
```

### Caching

PolyId caches `id <=> uuid` translations in memory by default. Lookups populate
the cache as they resolve, and saving a record caches its mapping. Loading
records does not, so an ordinary query costs nothing extra.

To improve performance, set it to a shared cache store such as Redis or `Rails.cache`.

```ruby
# config/environments/production.rb
config.cache_store = :redis_cache_store, {
  url: ENV.fetch("REDIS_URL"),
}

# config/initializers/polyid.rb
PolyId.cache = Rails.cache
```

Entries expire after a month by default. Since an `id <=> uuid` mapping never
changes, expiry only costs a re-query — but it matters operationally:

```ruby
PolyId.cache_ttl = 1.week
PolyId.cache_ttl = nil    # never expire
```

Redis `volatile-lru`, `volatile-ttl`, and `volatile-random` only ever evict keys
that carry a TTL, so entries written without one are never reclaimed and will
crowd out keys that can be. Under `noeviction` — Redis's default — a full
instance starts refusing writes instead of making room. Leave the TTL set unless
your store is configured with an `allkeys-*` policy.

----
## Contributing

Yes please  :)

1. Fork it
1. Create your feature branch (`git checkout -b my-feature`)
1. Ensure the tests pass (`bundle exec rspec`)
1. Commit your changes (`git commit -am 'awesome new feature'`)
1. Push your branch (`git push origin my-feature`)
1. Create a Pull Request
