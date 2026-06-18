require "factory_bot"

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end

FactoryBot.define do
  factory :user do
    name { Faker::Name.name }
    uuid { SecureRandom.uuid }
  end

  factory :account do
    name { Faker::Name.name }
  end

  factory :widget do
    name { Faker::Name.name }
  end

  factory :membership do
    name { Faker::Name.name }
    uuid { SecureRandom.uuid }
    external_id { SecureRandom.hex(8) }
  end
end
