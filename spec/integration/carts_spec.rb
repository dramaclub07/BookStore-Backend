require 'rails_helper'

RSpec.describe Api::V1::CartsController, type: :request do
  let(:user) { create(:user) }
  let(:book) { create(:book, book_mrp: 100, discounted_price: 80, quantity: 10) }
  let(:token) { JwtService.encode(user_id: user.id) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  describe 'POST /api/v1/cart/add' do
    context 'with valid parameters' do
      it 'adds a new item to the cart' do
        post '/api/v1/cart/add', params: { book_id: book.id, quantity: 2 }, headers: headers, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:success]).to be true
        expect(json[:message]).to eq('Cart updated successfully.') # Matches add_or_update_cart
        expect(user.carts.count).to eq(1)
        expect(user.carts.first.quantity).to eq(2)
      end

      it 'overwrites quantity of existing item' do
        create(:cart, user: user, book: book, quantity: 1, is_deleted: false)
        post '/api/v1/cart/add', params: { book_id: book.id, quantity: 2 }, headers: headers, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:success]).to be true
        expect(user.carts.first.quantity).to eq(2) # Overwrites, not increases
      end

      it 'accepts nested cart parameters' do
        post '/api/v1/cart/add', params: { cart: { book_id: book.id, quantity: 2 } }, headers: headers, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:success]).to be true
      end
    end

    context 'with invalid parameters' do
      it 'fails with nil book_id' do
        post '/api/v1/cart/add', params: { quantity: 2 }, headers: headers, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:success]).to be false
        expect(json[:message]).to eq('Invalid quantity.')
      end

      it 'fails with zero quantity' do
        post '/api/v1/cart/add', params: { book_id: book.id, quantity: 0 }, headers: headers, as: :json
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
    context 'with active cart items' do
      before do
        create(:cart, user: user, book: book, quantity: 2, is_deleted: false)
        create(:cart, user: user, book: create(:book, book_mrp: 50, discounted_price: nil), quantity: 1, is_deleted: false)
      end

      it 'returns summary with totals' do
        get '/api/v1/cart/summary', headers: headers, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:success]).to be true
        expect(json[:total_items]).to eq(3)
        expect(json[:total_price].to_f).to eq(210.0) # Handle stringified number
      end
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