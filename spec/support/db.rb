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
  end
end

# Models
class User < ActiveRecord::Base
end
