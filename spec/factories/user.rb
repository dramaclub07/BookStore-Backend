FactoryBot.define do
  factory :user do
    full_name { Faker::Name.name }
    sequence(:email) { |n| "user#{n}@gmail.com" } # Already unique, good
    password { 'Password@123' }
    sequence(:mobile_number) { |n| "9#{format('%09d', n)}" } # Unique: 9000000001, 9000000002, etc.

    trait :with_facebook do
      provider { 'facebook' }
      uid { Faker::Number.number(digits: 15) }
    end

    trait :with_google do
      provider { 'google' }
      uid { Faker::Number.number(digits: 15) }
    end
  end
end