require 'rails_helper'

RSpec.describe ReviewService do
  let!(:user) { create(:user, full_name: "Demetrius Braun") }  
  let!(:book) { create(:book) }
  let!(:review) { create(:review, user: user, book: book, rating: 4, comment: "Good book") }

  describe ".create_review" do
    it "creates a review successfully" do
      params = { rating: 5, comment: "Awesome read!" }
      result = ReviewService.create_review(book, user, params)

      expect(result[:success]).to be true
      expect(result[:review]).to be_persisted
      expect(result[:review].rating).to eq(5)
      expect(result[:review].comment).to eq("Awesome read!")
    end
  end

  describe ".get_reviews" do
    it "returns all reviews for a book" do
      reviews = ReviewService.get_reviews(book)

      expect(reviews).to include(
        a_hash_including(
          id: review.id,
          user_id: review.user_id,
          user_name: review.user.full_name, # Ensure this matches your User model
          book_id: review.book_id,
          rating: review.rating,
          comment: review.comment
        )
      )
    end
  end

  describe ".get_review" do
    it "returns a specific review" do
      fetched_review = ReviewService.get_review(book, review.id)
      expect(fetched_review).to eq(review)
    end
  end

  describe ".delete_review" do
    it "deletes a review" do
      result = ReviewService.delete_review(book, review.id)
      expect(result[:success]).to be true
      expect(Review.find_by(id: review.id)).to be_nil
    end
  end
end