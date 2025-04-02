require 'rails_helper'

RSpec.describe Wishlist, type: :model do
  # Factories (assumed; adjust as per your setup)
  let(:user) { create(:user) }
  let(:book) { create(:book) }
  let(:wishlist) { create(:wishlist, user: user, book: book) }

  # Associations
  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:book) }
  end

  # Validations
  describe "validations" do
    context "presence of user_id" do
      it "is invalid without a user_id" do
        wishlist = build(:wishlist, user_id: nil, book: book)
        expect(wishlist).not_to be_valid
        expect(wishlist.errors[:user_id]).to include("can't be blank")
      end

      it "is valid with a user_id" do
        wishlist = build(:wishlist, user: user, book: book)
        expect(wishlist).to be_valid
      end
    end

    context "uniqueness of book_id scoped to user_id" do
      let(:another_book) { create(:book) }

      it "is valid when adding a different book for the same user" do
        create(:wishlist, user: user, book: book) # First wishlist entry
        new_wishlist = build(:wishlist, user: user, book: another_book)
        expect(new_wishlist).to be_valid
      end

      it "is invalid when adding the same book for the same user" do
        create(:wishlist, user: user, book: book) # First wishlist entry
        duplicate_wishlist = build(:wishlist, user: user, book: book)
        expect(duplicate_wishlist).not_to be_valid
        expect(duplicate_wishlist.errors[:book_id]).to include("has already been added to wishlist")
      end

      it "is valid when adding the same book for a different user" do
        another_user = create(:user)
        create(:wishlist, user: user, book: book) # First user's wishlist
        new_wishlist = build(:wishlist, user: another_user, book: book)
        expect(new_wishlist).to be_valid
      end
    end
  end
end