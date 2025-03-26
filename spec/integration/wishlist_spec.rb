require 'rails_helper'

RSpec.describe Api::V1::WishlistsController, type: :controller do
  let(:user) { create(:user) }
  let(:book) { create(:book) }
  let(:valid_token) { JwtService.encode(user_id: user.id) }
  let(:invalid_token) { 'invalid.token.here' } # Will raise JWT::DecodeError
  let(:headers) { { 'Authorization' => "Bearer #{valid_token}", 'Content-Type' => 'application/json' } }

  def json
    JSON.parse(response.body, symbolize_names: true)
  rescue JSON::ParserError => e
    puts "Failed to parse JSON response: #{response.body}"
    return {}
  end

  describe 'before_action :authorize_request' do
    context 'with valid token and existing user' do
      it 'sets @current_user' do
        request.headers.merge!(headers)
        get :index, params: {} # Matches GET /api/v1/wishlists/fetch
        expect(response).to have_http_status(:ok)
        expect(controller.instance_variable_get(:@current_user)).to eq(user)
      end
    end

    context 'with no Authorization header' do
      it 'returns unauthorized' do
        get :index, params: {}
        expect(response).to have_http_status(:unauthorized)
        expect(json[:success]).to be false
        expect(json[:message]).to eq('Unauthorized - Missing token')
      end
    end

    context 'with invalid token' do
      it 'returns unauthorized due to JWT decode error' do
        request.headers['Authorization'] = "Bearer #{invalid_token}"
        get :index, params: {}
        expect(response).to have_http_status(:unauthorized)
        expect(json[:success]).to be false
        expect(json[:message]).to eq('Unauthorized - Invalid token')
      end
    end

    context 'with token for non-existent user' do
      it 'returns unauthorized due to RecordNotFound' do
        non_existent_token = JwtService.encode(user_id: 999)
        request.headers['Authorization'] = "Bearer #{non_existent_token}"
        get :index, params: {}
        expect(response).to have_http_status(:unauthorized)
        expect(json[:success]).to be false
        expect(json[:message]).to eq('Unauthorized - User not found')
      end
    end
  end

  describe 'GET #index' do
    context 'when authenticated' do
      before do
        allow(controller).to receive(:authorize_request) { controller.instance_variable_set(:@current_user, user) }
        request.headers.merge!(headers)
      end

      it 'returns the wishlist successfully' do
        allow_any_instance_of(WishlistService).to receive(:fetch_wishlist).and_return(
          { success: true, wishlist: [{ book_id: book.id }] }
        )
        get :index, params: {} # Matches GET /api/v1/wishlists/fetch
        expect(response).to have_http_status(:ok)
        expect(json[:success]).to be true
        expect(json[:wishlist]).to eq([{ book_id: book.id }])
      end
    end
  end

  describe 'POST #toggle' do
    context 'when authenticated' do
      before do
        allow(controller).to receive(:authorize_request) { controller.instance_variable_set(:@current_user, user) }
        request.headers.merge!(headers)
      end

      it 'toggles a book into the wishlist successfully' do
        allow_any_instance_of(WishlistService).to receive(:toggle_wishlist).with(book.id.to_s).and_return(
          { success: true, message: 'Book added to wishlist' }
        )
        post :toggle, params: { book_id: book.id } # Matches POST /api/v1/wishlists/toggle/:book_id
        expect(response).to have_http_status(:ok)
        expect(json[:success]).to be true
        expect(json[:message]).to eq('Book added to wishlist')
      end

      it 'toggles a book out of the wishlist successfully' do
        allow_any_instance_of(WishlistService).to receive(:toggle_wishlist).with(book.id.to_s).and_return(
          { success: true, message: 'Book removed from wishlist' }
        )
        post :toggle, params: { book_id: book.id }
        expect(response).to have_http_status(:ok)
        expect(json[:success]).to be true
        expect(json[:message]).to eq('Book removed from wishlist')
      end

      it 'handles missing book_id gracefully' do
        allow_any_instance_of(WishlistService).to receive(:toggle_wishlist).with('').and_return(
          { success: false, message: 'Book ID is required' }
        )
        post :toggle, params: { book_id: '' } # Still requires book_id in URL, use empty string
        expect(response).to have_http_status(:ok)
        expect(json[:success]).to be false
        expect(json[:message]).to eq('Book ID is required')
      end
    end
  end
end