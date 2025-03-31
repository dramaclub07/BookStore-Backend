require 'rails_helper'

RSpec.describe Api::V1::WishlistsController, type: :request do
  let(:user) { create(:user) }
  let(:book) { create(:book) }
  let(:token) { JwtService.encode_access_token(user_id: user.id) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  describe 'GET #index' do
    context 'when user is authenticated' do
      before do
        allow_any_instance_of(WishlistService).to receive(:fetch_wishlist).and_return({ success: true, wishlist: [] })
      end

      it 'returns the wishlist successfully' do
        get '/api/v1/wishlists', headers: headers
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response).to be_a(Hash)
        expect(json_response['success']).to be true
        expect(json_response['wishlist']).to eq([])
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized due to missing token' do
        get '/api/v1/wishlists'
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['message']).to eq('Unauthorized - Missing token')
      end
    end

    context 'when token is invalid' do
      it 'returns unauthorized due to invalid token' do
        get '/api/v1/wishlists', headers: { 'Authorization' => 'Bearer invalid_token' }
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['message']).to eq('Unauthorized - Invalid or expired access token')
      end
    end

    context 'when user is not found' do
      let(:non_existent_user_id) { 9999999 }
      let(:invalid_token) { JwtService.encode_access_token(user_id: non_existent_user_id) }

      before do
        User.where(id: non_existent_user_id).destroy_all
      end

      it 'returns unauthorized due to user not found' do
        get '/api/v1/wishlists', headers: { 'Authorization' => "Bearer #{invalid_token}" }
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Unauthorized - User not found')
      end
    end
  end

  describe 'POST #toggle' do
    context 'when authenticated' do
      it 'toggles a book into the wishlist successfully' do
        allow_any_instance_of(WishlistService).to receive(:toggle_wishlist).with(book.id).and_return({ success: true, message: 'Book added to wishlist' })
        post '/api/v1/wishlists', params: { book_id: book.id }, headers: headers
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response).to be_a(Hash)
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Book added to wishlist')
      end

      it 'toggles a book out of the wishlist successfully' do
        allow_any_instance_of(WishlistService).to receive(:toggle_wishlist).with(book.id).and_return({ success: true, message: 'Book removed from wishlist' })
        post '/api/v1/wishlists', params: { book_id: book.id }, headers: headers
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response).to be_a(Hash)
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Book removed from wishlist')
      end

      it 'handles missing book_id gracefully' do
        allow_any_instance_of(WishlistService).to receive(:toggle_wishlist).with(nil).and_return({ success: false, message: 'Book ID is required' })
        post '/api/v1/wishlists', params: {}, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Book ID is required')
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized due to missing token' do
        post '/api/v1/wishlists', params: { book_id: book.id }
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['message']).to eq('Unauthorized - Missing token')
      end
    end

    context 'when token is invalid' do
      it 'returns unauthorized due to invalid token' do
        post '/api/v1/wishlists', params: { book_id: book.id }, headers: { 'Authorization' => 'Bearer invalid_token' }
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['message']).to eq('Unauthorized - Invalid or expired access token')
      end
    end

    context 'when user is not found' do
      let(:non_existent_user_id) { 9999999 }
      let(:invalid_token) { JwtService.encode_access_token(user_id: non_existent_user_id) }

      before do
        User.where(id: non_existent_user_id).destroy_all
      end

      it 'returns unauthorized due to user not found' do
        post '/api/v1/wishlists', params: { book_id: book.id }, headers: { 'Authorization' => "Bearer #{invalid_token}" }
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Unauthorized - User not found')
      end
    end
  end
end