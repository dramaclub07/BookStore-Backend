require 'rails_helper'

RSpec.describe Api::V1::WishlistsController, type: :request do
  before(:all) do
    Rails.application.reload_routes!
    puts "Wishlist Routes: #{Rails.application.routes.routes.map { |r| r.path.spec.to_s }.grep(/wishlists/).join(', ')}"
    puts "Loaded Controllers: #{ApplicationController.descendants.map(&:name).join(', ')}"
  end

  let(:user) { create(:user) }
  let(:book) { create(:book) }
  let(:token) { JwtService.encode(user_id: user.id) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  describe 'GET /api/v1/wishlists' do
    context 'when user is authenticated' do
      before do
        create(:wishlist, user: user, book: book, is_deleted: false)
      end

      it 'returns the wishlist successfully' do
        get '/api/v1/wishlists', headers: headers, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:success]).to be true
        expect(json[:wishlist]).to be_an(Array)
        expect(json[:wishlist].first[:book_id]).to eq(book.id)
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        get '/api/v1/wishlists', as: :json
        puts "Response body: #{response.body}" # Debug
        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:errors]).to eq('Unauthorized - Missing token')
      end
    end
  end

  describe 'POST /api/v1/wishlists' do
    context 'when user is authenticated and book exists' do
      it 'toggles the wishlist status successfully' do
        post '/api/v1/wishlists', params: { book_id: book.id }, headers: headers, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:success]).to be true
        expect(json[:message]).to eq('Book added to wishlist')
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        post '/api/v1/wishlists', params: { book_id: book.id }, as: :json
        puts "Response body: #{response.body}" # Debug
        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:errors]).to eq('Unauthorized - Missing token')
      end
    end

    context 'when book_id is invalid' do
      it 'returns unprocessable entity' do
        post '/api/v1/wishlists', params: { book_id: nil }, headers: headers, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:success]).to be false
        expect(json[:message]).to eq('Invalid book_id')
      end
    end

    context 'when book is not found or unavailable' do
      let(:unavailable_book) { create(:book, is_deleted: true) }

      it 'returns unprocessable entity' do
        post '/api/v1/wishlists', params: { book_id: unavailable_book.id }, headers: headers, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:success]).to be false
        expect(json[:message]).to eq('Book not found or unavailable')
      end
    end
  end
end