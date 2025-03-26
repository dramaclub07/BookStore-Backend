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
    end
  end
end