# Schema setup for test database
ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :name
    t.string :email
    t.timestamps
  end
end
