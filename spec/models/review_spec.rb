require 'rails_helper'

RSpec.describe Review, type: :model do
  # Factories (assumed; adjust as per your setup)
  let(:user) { create(:user) }
  let(:book) { create(:book) }
  let(:review) { create(:review, user: user, book: book, rating: 4, comment: "Great book!") }

  # Associations
  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:book) }
  end

  # Validations
  describe "validations" do
    context "presence of rating" do
      it "is invalid without a rating" do
        review = build(:review, rating: nil, user: user, book: book, comment: "Nice read")
        expect(review).not_to be_valid
        expect(review.errors[:rating]).to include("can't be blank")
      end

      it "is valid with a rating" do
        review = build(:review, rating: 3, user: user, book: book, comment: "Good book")
        expect(review).to be_valid
      end
    end

    context "inclusion of rating between 1 and 5" do
      it "is invalid with a rating less than 1" do
        review = build(:review, rating: 0, user: user, book: book, comment: "Bad rating")
        expect(review).not_to be_valid
        expect(review.errors[:rating]).to include("is not included in the list")
      end

      it "is invalid with a rating greater than 5" do
        review = build(:review, rating: 6, user: user, book: book, comment: "Too high")
        expect(review).not_to be_valid
        expect(review.errors[:rating]).to include("is not included in the list")
      end

      it "is valid with a rating between 1 and 5" do
        review = build(:review, rating: 2, user: user, book: book, comment: "Okay book")
        expect(review).to be_valid
      end
    end

    context "presence of comment" do
      it "is invalid without a comment" do
        review = build(:review, rating: 3, user: user, book: book, comment: nil)
        expect(review).not_to be_valid
        expect(review.errors[:comment]).to include("can't be blank")
      end

      it "is valid with a comment" do
        review = build(:review, rating: 4, user: user, book: book, comment: "Loved it!")
        expect(review).to be_valid
      end
    end
  end
end