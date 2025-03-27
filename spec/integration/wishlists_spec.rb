require 'rails_helper'

RSpec.describe Api::V1::WishlistsController, type: :request do
  # Force reload routes before running tests
  before(:all) do
    Rails.application.reload_routes!
  end

  let(:user) { create(:user) }
  let(:book) { create(:book) }
  let(:token) { JwtService.encode(user_id: user.id) }
  let(:headers) { { 'Authorization' => "Bearer #{access_token}" } }

  describe 'GET /api/v1/wishlists/fetch' do
    context 'when user is authenticated' do
      before do
        create(:wishlist, user: user, book: book, is_deleted: false)
      end

      it 'returns the wishlist successfully' do
        get '/api/v1/wishlists/fetch', headers: headers, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:success]).to be true
        expect(json[:wishlist]).to be_an(Array)
        expect(json[:wishlist].first[:book_id]).to eq(book.id)
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        get '/api/v1/wishlists/fetch', as: :json
        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:errors]).to eq('Unauthorized - Missing token')
      end
    end
  end

  describe 'POST /api/v1/wishlists/toggle/:book_id' do
    context 'when user is authenticated and book exists' do
      it 'toggles the wishlist status successfully' do
        post "/api/v1/wishlists/toggle/#{book.id}", headers: headers, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:success]).to be true
        expect(json[:message]).to eq('Book added to wishlist')
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        post "/api/v1/wishlists/toggle/#{book.id}", as: :json
        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:errors]).to eq('Unauthorized - Missing token')
      end
    end
  end
end