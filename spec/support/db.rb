require "active_record"
require "securerandom"

ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: ":memory:"
)

RSpec.configure do |config|
  config.around(:each) do |example|
    ActiveRecord::Base.connection.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end

ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :name
    t.string :uuid, null: false
  end

  add_index :users, :uuid, unique: true

  create_table :accounts, force: true do |t|
    t.string :name
    t.binary :uuid, limit: 16
  end

  create_table :widgets, force: true do |t|
    t.string :name
    t.string :public_id
  end

  create_table :auto_users, force: true do |t|
    t.string :name
    t.string :uuid, null: false
  end

  add_index :auto_users, :uuid, unique: true

  create_table :legacy_users, force: true do |t|
    t.string :name
  end
end

class User < ActiveRecord::Base
  polyid
end

class Account < ActiveRecord::Base
  polyid
end

class Widget < ActiveRecord::Base
  polyid uuid_attribute: :public_id, uuid_generator: -> { "00000000-0000-7000-8000-000000000001" }
end

class AutoUser < ActiveRecord::Base
end

class LegacyUser < ActiveRecord::Base
end
