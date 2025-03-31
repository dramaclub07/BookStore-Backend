FactoryBot.define do
  factory :user do
    full_name { Faker::Name.name }
    sequence(:email) { |n| "user#{n}@gmail.com" } # Already unique, good
    password { "Password@123" }
    sequence(:mobile_number) { |n| "9#{format('%09d', n)}" } # Unique: 9000000001, etc.

    trait :with_facebook do
      facebook_id { Faker::Number.number(digits: 15) } # Adjusted to match schema
    end

    trait :with_google do
      google_id { Faker::Number.number(digits: 15) }
    end

    trait :with_github do
      github_id { Faker::Number.number(digits: 15) }
    end
  end
end