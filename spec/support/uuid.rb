# sqlite coerces a string id to its leading digits, so a random uuid can
# accidentally match a small primary key.  use this when asserting a miss.
UNKNOWN_UUID = 'deadbeef-0000-4000-8000-000000000000'.freeze
