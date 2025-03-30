FactoryBot.define do
  factory :user do
    full_name { Faker::Name.name }
    sequence(:email) { |n| "user#{n}@gmail.com" }
    password { 'Password@123' }
    sequence(:mobile_number) { |n| "9#{n.to_s.rjust(9, '0')}" }
    role { 'user' }

    trait :admin do
      role { 'admin' }
    end

    trait :with_google do
      google_id { Faker::Alphanumeric.alphanumeric(number: 21) }
      password { nil }
      mobile_number { nil }
    end

    trait :with_facebook do
      facebook_id { Faker::Alphanumeric.alphanumeric(number: 21) }
      password { nil }
      mobile_number { nil }
    end
  end
end