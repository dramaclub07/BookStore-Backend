FactoryBot.define do
  factory :user do
    full_name { "John Doe" }
    email { Faker::Internet.email(domain: 'gmail.com') } # ✅ Ensures the email matches the regex
    mobile_number { "9876543210" } 
    password { "password123" }
  end
end
