# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    full_name { "John Doe" }
    email { Faker::Internet.email }
    password { "password123" }
    mobile_number { Faker::Number.number(digits: 10) }
  end
end
