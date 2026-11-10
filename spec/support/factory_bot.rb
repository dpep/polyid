require "factory_bot"

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end

FactoryBot.define do
  # letter-led, so a uuid that escapes translation integer-casts to 0, which no
  # row has, rather than to whichever id its leading digits happen to spell
  sequence(:uuid) { "f#{SecureRandom.uuid[1..]}" }

  factory :user do
    name { Faker::Name.name }
    uuid { generate(:uuid) }
  end

  factory :account do
    name { Faker::Name.name }
    uuid { generate(:uuid) }
  end

  factory :dog do
    uuid { generate(:uuid) }
  end

  factory :widget do
    name { Faker::Name.name }
  end
end
