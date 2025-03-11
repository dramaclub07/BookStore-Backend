FactoryBot.define do
    factory :wishlist do
      association :user
      association :book
      is_deleted { false }
    end
  end
  