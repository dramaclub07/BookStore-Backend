# spec/factories/addresses.rb
FactoryBot.define do
  factory :address do
    street { "123 Main St" }
    city { "Anytown" }
    state { "CA" }
    zip_code { "12345" }
    country { "USA" }
    address_type { "home" }
    is_deleted { false }
    user
  end
end