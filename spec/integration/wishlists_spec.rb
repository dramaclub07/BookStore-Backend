require 'rails_helper'

RSpec.describe Api::V1::WishlistsController, type: :request do
  let(:user) { create(:user) }
  let(:book) { create(:book) }
  let(:token) { JwtService.encode(user_id: user.id) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  describe 'GET /api/v1/wishlists/fetch' do
    context 'when user is authenticated' do
      before do
        # Ensure user exists and token is valid
        puts "User ID: #{user.id}"
        puts "Generated Token: #{token}"
        decoded = JwtService.decode(token)
        puts "Decoded Token: #{decoded.inspect}"
        allow_any_instance_of(WishlistService).to receive(:fetch_wishlist).and_return({ success: true, wishlist: [] })
      end

      it 'returns the wishlist successfully' do
        get '/api/v1/wishlists/fetch', headers: headers
        puts "Response Status: #{response.status}"
        puts "Response Body: #{response.body}"
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response).to be_a(Hash)
        expect(json_response['success']).to be true
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        get '/api/v1/wishlists/fetch'
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['message']).to eq('Unauthorized - Missing token')
      end
    end
  end

  describe 'POST /api/v1/wishlists/toggle/:book_id' do
    context 'when user is authenticated and book exists' do
      it 'toggles the wishlist status successfully' do
        post "/api/v1/wishlists/toggle/#{book.id}", headers: headers
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to be_a(Hash)
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        post "/api/v1/wishlists/toggle/#{book.id}"
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['message']).to eq('Unauthorized - Missing token')
      end
    end
  end
end