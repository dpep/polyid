require "active_record"
require "securerandom"

# Configure ActiveRecord to use SQLite in-memory database
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: ':memory:'
)

RSpec.configure do |config|
  # Reset database between test runs
  config.around(:each) do |example|
    ActiveRecord::Base.connection.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end

# Schema
ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :name
    t.string :uuid, null: false
  end

  create_table :accounts, force: true do |t|
    t.string :name
    t.string :uuid
  end

  create_table :widgets, force: true do |t|
    t.string :name
    t.string :public_id
  end
end

# Models
class User < ActiveRecord::Base
  polyid
end

class Account < ActiveRecord::Base
  polyid
end

class Widget < ActiveRecord::Base
  polyid uuid_attribute: :public_id, uuid_generator: -> { "00000000-0000-7000-8000-000000000001" }
end
