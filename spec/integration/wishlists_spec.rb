# spec/integration/wishlists_spec.rb
require 'rails_helper'

RSpec.describe "Api::V1::WishlistsController", type: :request do
  let(:user) { create(:user) }
  let(:book) { create(:book) }
  let(:token) { JwtService.encode_access_token(user_id: user.id, exp: 1.hour.from_now.to_i) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  # Ensure consistent secret key and clean database
  before(:all) do
    ENV['JWT_SECRET_KEY'] = 'test-secret' # Match JwtService fallback
    DatabaseCleaner.clean_with(:truncation) # Reset database
  end

  after(:all) do
    DatabaseCleaner.clean_with(:truncation) # Clean up after all tests
  end

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
      let(:invalid_token) { "Bearer eyJhbGciOiJIUzI1NiJ9.#{Base64.urlsafe_encode64({ user_id: non_existent_user_id }.to_json)}.signature" }
    
      it 'returns unauthorized due to user not found' do
        allow(JwtService).to receive(:decode_access_token).and_return({ user_id: non_existent_user_id })
        allow(User).to receive(:find).with(non_existent_user_id).and_raise(ActiveRecord::RecordNotFound)
        get '/api/v1/wishlists', headers: { 'Authorization' => invalid_token }
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        puts "GET #index Response body: #{response.body}" # Debugging output
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Unauthorized - User not found')
      end
    end
  end

  describe 'POST #toggle' do
    context 'when authenticated' do
      it 'toggles a book into the wishlist successfully' do
        allow_any_instance_of(WishlistService).to receive(:toggle_wishlist).with(book.id.to_s).and_return({ success: true, message: 'Book added to wishlist' })
        post '/api/v1/wishlists', params: { book_id: book.id }, headers: headers
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response).to be_a(Hash)
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Book added to wishlist')
      end

      it 'toggles a book out of the wishlist successfully' do
        allow_any_instance_of(WishlistService).to receive(:toggle_wishlist).with(book.id.to_s).and_return({ success: true, message: 'Book removed from wishlist' })
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
      let(:invalid_token) { "Bearer eyJhbGciOiJIUzI1NiJ9.#{Base64.urlsafe_encode64({ user_id: non_existent_user_id }.to_json)}.signature" }
    
      it 'returns unauthorized due to user not found' do
        allow(JwtService).to receive(:decode_access_token).and_return({ user_id: non_existent_user_id })
        allow(User).to receive(:find).with(non_existent_user_id).and_raise(ActiveRecord::RecordNotFound)
        post '/api/v1/wishlists', params: { book_id: book.id }, headers: { 'Authorization' => invalid_token }
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        puts "POST #toggle Response body: #{response.body}" # Debugging output
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Unauthorized - User not found')
      end
    end
  end
end