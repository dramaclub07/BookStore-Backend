require 'rails_helper'

RSpec.describe Api::V1::ReviewsController, type: :request do
  let(:user) { create(:user) }
  let(:book) { create(:book) }
  let(:review) { create(:review, user: user, book: book, rating: 4, comment: 'Good book') }

  describe '.create_review' do
    it 'creates a review successfully' do
      params = { rating: 5, comment: 'Awesome read!' }
      result = ReviewService.create_review(book, user, params)
      expect(result[:success]).to be true
      expect(result[:review]).to be_persisted
      expect(result[:review].rating).to eq(5)
      expect(result[:review].comment).to eq('Awesome read!')
    end

    it 'fails with invalid rating' do
      params = { rating: 6, comment: 'Too high!' }
      result = ReviewService.create_review(book, user, params)
      expect(result[:success]).to be false
      expect(result[:errors]).to include('Rating is not included in the list') # Match actual validation
    end

    it 'fails with missing rating' do
      params = { comment: 'No rating!' }
      result = ReviewService.create_review(book, user, params)
      expect(result[:success]).to be false
      expect(result[:errors]).to include("Rating can't be blank") # Assuming presence validation
    end
  end

  describe '.get_reviews' do
    it 'returns all reviews for a book' do
      review # Ensure review is created
      reviews = ReviewService.get_reviews(book)
      expect(reviews).to be_an(Array)
      expect(reviews.size).to eq(1)
      review_hash = reviews.first
      expect(review_hash[:id]).to eq(review.id)
      expect(review_hash[:rating]).to eq(4)
      expect(review_hash[:comment]).to eq('Good book')
      expect(review_hash[:user_id]).to eq(user.id)
      expect(review_hash[:book_id]).to eq(book.id)
    end

    it 'returns empty when no reviews exist' do
      book.reviews.destroy_all
      reviews = ReviewService.get_reviews(book)
      expect(reviews).to be_empty
    end
  end

  describe '.get_review' do
    it 'returns a specific review' do
      fetched_review = ReviewService.get_review(book, review.id)
      expect(fetched_review).to eq(review)
    end

    it 'returns nil when review doesn’t exist' do
      fetched_review = ReviewService.get_review(book, 999)
      expect(fetched_review).to be_nil
    end
  end

  describe '.delete_review' do
    it 'deletes a review successfully' do
      result = ReviewService.delete_review(book, review.id)
      expect(result[:success]).to be true
      expect(Review.find_by(id: review.id)).to be_nil
    end

    it 'returns failure when review doesn’t exist' do
      result = ReviewService.delete_review(book, 999)
      expect(result[:success]).to be false
      expect(result[:message]).to eq('Review not found')
    end
  end
end