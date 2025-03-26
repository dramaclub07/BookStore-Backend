# FactoryBot.define do
#   factory :user do
#     full_name { Faker::Name.name }
#     sequence(:email) { |n| "user#{n}@#{%w[gmail.com yahoo.com outlook.com].sample}".downcase }
#     password { 'Password@123' }
#     mobile_number { "9#{Faker::Number.leading_zero_number(digits: 9)}" }
#   end
# end


FactoryBot.define do
  factory :user do
    full_name { Faker::Name.name }
    sequence(:email) { |n| "user#{n}@#{%w[gmail.com yahoo.com outlook.com].sample}".downcase }
    password { 'Password@123' }
    mobile_number { "9#{Faker::Number.number(digits: 9)}" }

    # Trait for Facebook authentication
    trait :with_facebook do
      provider { 'facebook' }
      uid { Faker::Number.number(digits: 15) }
    end

    # Trait for Google authentication
    trait :with_google do
      provider { 'google' }
      uid { Faker::Number.number(digits: 15) }
    end
  end
end
