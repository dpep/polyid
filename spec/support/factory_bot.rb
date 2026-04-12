require "factory_bot"

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end

FactoryBot.define do
  factory :user do
    name { Faker::Name.name }
  end

  factory :account do
    name { Faker::Name.name }
  end

  factory :widget do
    name { Faker::Name.name }
  end
end
