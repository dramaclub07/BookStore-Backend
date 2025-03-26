require 'rails_helper'

RSpec.describe Api::V1::ReviewsController, type: :request do
  let(:user) { create(:user) }
  let(:book) { create(:book) }
  let(:review) { create(:review, user: user, book: book) }
  let(:token) { JwtService.encode(user_id: user.id) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  describe 'GET /api/v1/books/:book_id/reviews' do
    context 'when reviews exist' do
      before { create(:review, book: book) }

      it 'returns a list of reviews' do
        get "/api/v1/books/#{book.id}/reviews"
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to be_an(Array)
      end
    end
  end

  describe 'POST /api/v1/books/:book_id/reviews' do
    let(:valid_params) { { review: { rating: 5, comment: 'Great book!' } } }

    context 'when user is authenticated' do
      it 'creates a review successfully' do
        post "/api/v1/books/#{book.id}/reviews", params: valid_params, headers: headers
        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)['rating']).to eq(5)
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        post "/api/v1/books/#{book.id}/reviews", params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/books/:book_id/reviews/:id' do
    context 'when review exists' do
      it 'returns the review' do
        get "/api/v1/books/#{book.id}/reviews/#{review.id}", headers: headers
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['id']).to eq(review.id)
      end
    end

    context 'when review does not exist' do
      it 'returns not found' do
        get "/api/v1/books/#{book.id}/reviews/999", headers: headers
        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)['error']).to eq('Review not found')
      end
    end
  end

  describe 'DELETE /api/v1/books/:book_id/reviews/:id' do
    context 'when review exists and user is authenticated' do
      it 'deletes the review successfully' do
        delete "/api/v1/books/#{book.id}/reviews/#{review.id}", headers: headers
        expect(response).to have_http_status(:no_content)
      end
    end

    context 'when review does not exist' do
      it 'returns not found' do
        delete "/api/v1/books/#{book.id}/reviews/999", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end