FactoryBot.define do
  factory :user do
    full_name { "John Doe" }
    email { Faker::Internet.email(domain: 'gmail.com') } # ✅ Ensures the email matches the regex
    mobile_number { "9876543210" } 
    password { "password123" }
    full_name { Faker::Name.name }
    email { Faker::Internet.email(domain: %w[gmail.com yahoo.com outlook.com].sample) }
    password { 'Password@123' }
    mobile_number { "9#{Faker::Number.number(digits: 9)}" }
  end
end