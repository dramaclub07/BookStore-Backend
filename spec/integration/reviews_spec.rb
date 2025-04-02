require 'rails_helper'

RSpec.describe Api::V1::ReviewsController, type: :request do
  let(:user) { create(:user) }
  let(:book) { create(:book) }
  let(:review) { create(:review, user: user, book: book, rating: 4, comment: 'Good book') }
  let(:access_token) { JwtService.encode_access_token(user_id: user.id) }
  let(:headers) { { 'Authorization' => "Bearer #{access_token}" } }

  describe 'POST /api/v1/books/:book_id/reviews' do
    let(:valid_params) { { review: { rating: 5, comment: 'Awesome read!' } } }
    let(:invalid_params) { { review: { rating: 6, comment: 'Too high!' } } }

    context 'when authenticated' do
      it 'creates a review successfully' do
        post "/api/v1/books/#{book.id}/reviews", params: valid_params, headers: headers
        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['rating']).to eq(5)
        expect(json['comment']).to eq('Awesome read!')
        expect(json['user_id']).to eq(user.id)
        expect(json['book_id']).to eq(book.id)
      end

      it 'fails with invalid rating' do
        post "/api/v1/books/#{book.id}/reviews", params: invalid_params, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to include('Rating is not included in the list')
      end

      it 'fails with missing rating' do
        post "/api/v1/books/#{book.id}/reviews", params: { review: { comment: 'No rating!' } }, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to include("Rating can't be blank")
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        post "/api/v1/books/#{book.id}/reviews", params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when book is not found' do
      it 'returns not found' do
        post "/api/v1/books/999/reviews", params: valid_params, headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET /api/v1/books/:book_id/reviews' do
    context 'when reviews exist' do
      before { review } # Ensure review is created

      it 'returns all reviews for a book' do
        get "/api/v1/books/#{book.id}/reviews"
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json).to be_an(Array)
        expect(json.size).to eq(1)
        expect(json.first['id']).to eq(review.id)
        expect(json.first['rating']).to eq(4)
        expect(json.first['comment']).to eq('Good book')
        expect(json.first['user_id']).to eq(user.id)
        expect(json.first['book_id']).to eq(book.id)
      end
    end

    context 'when no reviews exist' do
      before { book.reviews.destroy_all }

      it 'returns an empty array' do
        get "/api/v1/books/#{book.id}/reviews"
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json).to be_empty
      end
    end

    context 'when book is not found' do
      it 'returns not found' do
        get "/api/v1/books/999/reviews"
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET /api/v1/books/:book_id/reviews/:id' do
    context 'when authenticated' do
      context 'when review exists' do
        it 'returns the specific review' do
          get "/api/v1/books/#{book.id}/reviews/#{review.id}", headers: headers
          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json['id']).to eq(review.id)
          expect(json['rating']).to eq(4)
          expect(json['comment']).to eq('Good book')
        end
      end

      context 'when review doesn’t exist' do
        it 'returns not found' do
          get "/api/v1/books/#{book.id}/reviews/999", headers: headers
          expect(response).to have_http_status(:not_found)
          json = JSON.parse(response.body)
          expect(json['error']).to eq('Review not found')
        end
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get "/api/v1/books/#{book.id}/reviews/#{review.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when book is not found' do
      it 'returns not found' do
        get "/api/v1/books/999/reviews/#{review.id}", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'DELETE /api/v1/books/:book_id/reviews/:id' do
    context 'when authenticated' do
      context 'when review exists' do
        it 'deletes the review successfully' do
          delete "/api/v1/books/#{book.id}/reviews/#{review.id}", headers: headers
          expect(response).to have_http_status(:no_content)
          expect(Review.find_by(id: review.id)).to be_nil
        end
      end

      context 'when review doesn’t exist' do
        it 'returns not found' do
          delete "/api/v1/books/#{book.id}/reviews/999", headers: headers
          expect(response).to have_http_status(:not_found)
          json = JSON.parse(response.body)
          expect(json['error']).to eq('Review not found')
        end
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        delete "/api/v1/books/#{book.id}/reviews/#{review.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when book is not found' do
      it 'returns not found' do
        delete "/api/v1/books/999/reviews/#{review.id}", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end