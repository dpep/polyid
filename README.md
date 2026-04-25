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

PolyId caches `id <=> uuid` translations in memory by default. The cache is warmed automatically when records are loaded and updated.

To improve performance, set it to a shared cache store such as Redis or `Rails.cache`.

```ruby
# config/environments/production.rb
config.cache_store = :redis_cache_store, {
  url: ENV.fetch("REDIS_URL"),
}

# config/initializers/polyid.rb
PolyId.cache = Rails.cache
```

----
## Contributing

Yes please  :)

1. Fork it
1. Create your feature branch (`git checkout -b my-feature`)
1. Ensure the tests pass (`bundle exec rspec`)
1. Commit your changes (`git commit -am 'awesome new feature'`)
1. Push your branch (`git push origin my-feature`)
1. Create a Pull Request
