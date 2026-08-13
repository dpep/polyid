# ActiveRecord casts a string id with `to_i`, so a uuid starting with a digit
# truncates to a small primary key and matches it.  use this to assert a miss.
UNKNOWN_UUID = "deadbeef-0000-4000-8000-000000000000".freeze
