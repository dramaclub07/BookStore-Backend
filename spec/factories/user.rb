FactoryBot.define do
  factory :user do
    full_name { Faker::Name.name }
    email { Faker::Internet.email(domain: %w[gmail.com yahoo.com outlook.com].sample) }
    password { 'Password@123' }
    mobile_number { "9#{Faker::Number.number(digits: 9)}" }
  end
end
