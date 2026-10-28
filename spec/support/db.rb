require "active_record"
require "securerandom"

ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: ":memory:"
)

module SqlQueries
  def sql_queries(&)
    queries = []
    record = ->(*, payload) { queries << payload[:sql] unless %w[SCHEMA TRANSACTION].include?(payload[:name]) }
    ActiveSupport::Notifications.subscribed(record, "sql.active_record", &)
    queries
  end
end

RSpec.configure do |config|
  config.include SqlQueries

  # non-joinable, as Rails' transactional fixtures are, so after_commit fires
  config.around(:each) do |example|
    ActiveRecord::Base.connection.transaction(joinable: false) do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end

ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :name
    t.string :uuid, null: false, index: { unique: true }
    t.references :account
    t.references :legacy_user
  end

  create_table :accounts, force: true do |t|
    t.string :name
    t.binary :uuid, limit: 16, index: { unique: true }
  end

  create_table :widgets, force: true do |t|
    t.string :name
    t.string :public_id, index: { unique: true }
    t.references :owner, polymorphic: true
  end

  create_table :legacy_users, force: true do |t|
    t.string :name
  end

  create_table :tokens, id: false, force: true do |t|
    t.binary :uuid, limit: 16, primary_key: true
  end

  create_table :orgs, force: true do |t|
    t.string :uuid, null: false, index: { unique: true }
  end

  # a foreign key onto the uuid rather than the id
  create_table :members, force: true do |t|
    t.string :uuid, null: false, index: { unique: true }
    t.string :org_uuid
  end

  create_table :animals, force: true do |t|
    t.string :type
    t.string :uuid, null: false, index: { unique: true }
  end
end

class User < ActiveRecord::Base
  belongs_to :account, optional: true
  belongs_to :legacy_user, optional: true
end

class Account < ActiveRecord::Base
  has_many :users
end

class Widget < ActiveRecord::Base
  belongs_to :owner, polymorphic: true, optional: true

  polyid uuid_attribute: :public_id, uuid_generator: -> { "00000000-0000-7000-8000-000000000001" }
end

class LegacyUser < ActiveRecord::Base
  has_many :users
end

class Token < ActiveRecord::Base
end

class Org < ActiveRecord::Base
end

class Member < ActiveRecord::Base
  belongs_to :org, primary_key: :uuid, foreign_key: :org_uuid, optional: true
end

class Animal < ActiveRecord::Base
end

class Dog < Animal
end
