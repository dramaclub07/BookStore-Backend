require 'rails_helper'

RSpec.describe Api::V1::CartsController, type: :request do
  let(:user) { create(:user) }
  let(:book) { create(:book, book_mrp: 100, discounted_price: 80) }
  let(:token) { JwtService.encode(user_id: user.id) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  describe 'POST /api/v1/cart/add' do
    let(:valid_params) { { book_id: book.id, quantity: 2 } }

    context 'when user is authenticated' do
      it 'adds an item to the cart' do
        post '/api/v1/cart/add', params: valid_params, headers: headers
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['success']).to be true
      end
    end

    context 'with invalid quantity' do
      it 'returns unprocessable entity' do
        post '/api/v1/cart/add', params: { book_id: book.id, quantity: 0 }, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['message']).to eq('Invalid quantity.')
      end
    end
  end

  describe 'GET /api/v1/cart' do
    it 'returns the user’s cart' do
      get '/api/v1/cart', headers: headers
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to be_a(Hash)
    end
  end

  describe 'PATCH /api/v1/cart/toggle_remove' do
    let(:params) { { book_id: book.id } }

    context 'with an existing cart item' do
      before do
        CartService.new(user).add_or_update_cart(book.id, 1)
      end

      it 'toggles the cart item status' do
        patch '/api/v1/cart/toggle_remove', params: params, headers: headers
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['success']).to be true
      end
    end
  end

  describe 'PATCH /api/v1/cart/update_quantity' do
    let(:valid_params) { { book_id: book.id, quantity: 3 } }

    context 'with an existing cart item' do
      before do
        CartService.new(user).add_or_update_cart(book.id, 1)
      end

      it 'updates the quantity successfully' do
        patch '/api/v1/cart/update_quantity', params: valid_params, headers: headers
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['success']).to be true
      end
    end

    context 'with invalid quantity' do
      it 'returns unprocessable entity' do
        patch '/api/v1/cart/update_quantity', params: { book_id: book.id, quantity: 0 }, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['message']).to eq('Invalid quantity.')
RSpec.describe Api::V1::CartsController, type: :controller do
  let(:user) { create(:user) }
  let(:book) { create(:book) }
  let(:auth_token) { JwtService.encode(user_id: user.id) }
  let(:headers) { { 'Authorization' => "Bearer #{auth_token}", 'Content-Type' => 'application/json' } }

  def json
    JSON.parse(response.body, symbolize_names: true)
  rescue JSON::ParserError => e
    puts "Failed to parse JSON response: #{response.body}"
    raise e
  end

  describe 'POST #add' do
    context 'with valid parameters' do
      before do
        allow(controller).to receive(:authenticate_request).and_return(true)
        controller.instance_variable_set(:@current_user, user)
        request.headers.merge!(headers)
      end

      it 'adds a book to the cart' do
        post :add, params: { book_id: book.id, quantity: 2 }
        expect(response).to have_http_status(:ok)
        expect(json[:success]).to be true
      end
    end

    context 'with invalid parameters' do
      before do
        allow(controller).to receive(:authenticate_request).and_return(true)
        controller.instance_variable_set(:@current_user, user)
        request.headers.merge!(headers)
      end

      it 'returns an error for missing book_id' do
        post :add, params: { quantity: 2 }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json[:success]).to be false
        expect(json[:message]).to eq('Invalid quantity.')
      end

      it 'returns an error for invalid quantity' do
        post :add, params: { book_id: book.id, quantity: 0 }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json[:success]).to be false
        expect(json[:message]).to eq('Invalid quantity.')
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        post :add, params: { book_id: book.id, quantity: 2 }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/cart/summary' do
    before do
      cart = build(:cart, user: user, book: book, quantity: 2, active: true)
      cart.save!
      puts "User ID: #{user.id}"
      puts "Cart Count for User: #{user.carts.active.count}"
      puts "Cart Details: #{user.carts.active.map { |c| { book_id: c.book_id, quantity: c.quantity, active: c.active, discounted_price: c.book.discounted_price } }}"
    end

    it 'returns the cart summary' do
      get '/api/v1/cart/summary', headers: headers
      puts "Token: #{token}"
      puts "Summary Status: #{response.status}"
      puts "Summary Body: #{response.body}"
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['total_items']).to eq(2)
      expect(json_response['total_price']).to eq(160)
  describe 'GET #summary' do
    context 'when authenticated' do
      before do
        allow(controller).to receive(:authenticate_request).and_return(true)
        controller.instance_variable_set(:@current_user, user)
        create(:cart, user: user, book: book, quantity: 2, is_deleted: false)
        request.headers.merge!(headers)
      end

      it 'returns the cart summary' do
        get :summary
        expect(response).to have_http_status(:ok)
        expect(json[:success]).to be true
        expect(json[:total_items]).to eq(2)
        expected_price = (book.discounted_price || book.book_mrp || 0) * 2
        expect(json[:total_price].to_f).to eq(expected_price)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get :summary
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT #toggle_remove' do
    context 'with valid parameters' do
      before do
        allow(controller).to receive(:authenticate_request).and_return(true)
        controller.instance_variable_set(:@current_user, user)
        create(:cart, user: user, book: book, is_deleted: false)
        request.headers.merge!(headers)
      end

      it 'toggles the cart item' do
        put :toggle_remove, params: { book_id: book.id }
        expect(response).to have_http_status(:ok)
        expect(json[:success]).to be true
      end
    end

    context 'with invalid parameters' do
      before do
        allow(controller).to receive(:authenticate_request).and_return(true)
        controller.instance_variable_set(:@current_user, user)
        request.headers.merge!(headers)
      end

      it 'returns an error for missing book_id' do
        put :toggle_remove, params: {}
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json[:success]).to be false
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        put :toggle_remove, params: { book_id: book.id }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET #index' do
    context 'when authenticated' do
      before do
        allow(controller).to receive(:authenticate_request).and_return(true)
        controller.instance_variable_set(:@current_user, user)
        create(:cart, user: user, book: book, is_deleted: false)
        request.headers.merge!(headers)
      end

      it 'returns the cart items' do
        get :index
        puts "GET #index response: #{json}" # Keep for debugging if needed
        expect(response).to have_http_status(:ok)
        expect(json[:success]).to be true
        expect(json[:cart].size).to eq(1) # Updated to match actual key
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT #update_quantity' do
    context 'with valid parameters' do
      before do
        allow(controller).to receive(:authenticate_request).and_return(true)
        controller.instance_variable_set(:@current_user, user)
        create(:cart, user: user, book: book, quantity: 1, is_deleted: false)
        request.headers.merge!(headers)
      end

      it 'updates the quantity of the cart item' do
        put :update_quantity, params: { book_id: book.id, quantity: 3 }
        puts "PUT #update_quantity response: #{json}" # Keep for debugging if needed
        expect(response).to have_http_status(:ok)
        expect(json[:success]).to be true
        expect(json[:cart][:quantity]).to eq(3) # Updated to match actual key
      end
    end

    context 'with invalid parameters' do
      before do
        allow(controller).to receive(:authenticate_request).and_return(true)
        controller.instance_variable_set(:@current_user, user)
        request.headers.merge!(headers)
      end

      it 'returns an error for missing book_id' do
        put :update_quantity, params: { quantity: 3 }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json[:success]).to be false
        expect(json[:message]).to eq('Invalid quantity.')
      end

      it 'returns an error for invalid quantity' do
        put :update_quantity, params: { book_id: book.id, quantity: 0 }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json[:success]).to be false
        expect(json[:message]).to eq('Invalid quantity.')
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        put :update_quantity, params: { book_id: book.id, quantity: 3 }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end