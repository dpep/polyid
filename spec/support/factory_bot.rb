require "factory_bot"

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end

FactoryBot.define do
  factory :user do
    name { Faker::Name.name }
    uuid { SecureRandom.uuid }
  end
end
