require 'rails_helper'

RSpec.describe Api::V1::CartsController, type: :request do
  let(:user) { create(:user) }
  let(:book) { create(:book, book_mrp: 100, discounted_price: 80, quantity: 10) }
  let(:token) { JwtService.encode(user_id: user.id) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  describe 'POST /api/v1/carts/:id' do
    context 'with valid parameters' do
      it 'adds a new item to the cart' do
        post "/api/v1/carts/#{book.id}", params: { quantity: 2 }, headers: headers, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:success]).to be true
        expect(json[:message]).to eq('Cart updated successfully.')
        expect(user.carts.count).to eq(1)
        expect(user.carts.first.quantity).to eq(2)
      end

      it 'overwrites quantity of existing item' do
        create(:cart, user: user, book: book, quantity: 1, is_deleted: false)
        post "/api/v1/carts/#{book.id}", params: { quantity: 2 }, headers: headers, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:success]).to be true
        expect(user.carts.first.quantity).to eq(2)
      end

      it 'accepts nested cart parameters' do
        post "/api/v1/carts/#{book.id}", params: { cart: { quantity: 2 } }, headers: headers, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:success]).to be true
      end
    end

    context 'with invalid parameters' do
      it 'fails with nil book_id' do
        post "/api/v1/carts/0", params: { quantity: 2 }, headers: headers, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:success]).to be false
        expect(json[:message]).to eq('Invalid book_id or quantity.')
      end

      it 'fails with zero quantity' do
        post "/api/v1/carts/#{book.id}", params: { quantity: 0 }, headers: headers, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:message]).to eq('Invalid book_id or quantity.')
      end

      it 'fails with insufficient stock' do
        post "/api/v1/carts/#{book.id}", params: { quantity: 15 }, headers: headers, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:message]).to eq('Not enough stock available.')
      end

      it 'fails with non-existent book' do
        post "/api/v1/carts/999", params: { quantity: 1 }, headers: headers, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:message]).to eq('Book not found or unavailable.')
      end
    end

    context 'authentication' do
      it 'fails without token' do
        post "/api/v1/carts/#{book.id}", params: { quantity: 2 }, as: :json
        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:message]).to eq('Unauthorized - Missing token')
      end

      it 'fails with invalid token' do
        post "/api/v1/carts/#{book.id}", params: { quantity: 2 }, headers: { 'Authorization' => 'Bearer invalid' }, as: :json
        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:message]).to eq('Unauthorized - Invalid token')
      end
    end
  end

  describe 'GET /api/v1/carts/summary' do
    context 'with active cart items' do
      before do
        create(:cart, user: user, book: book, quantity: 2, is_deleted: false)
        create(:cart, user: user, book: create(:book, book_mrp: 50, discounted_price: nil), quantity: 1, is_deleted: false)
      end

      it 'returns summary with totals' do
        get '/api/v1/carts/summary', headers: headers, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:success]).to be true
        expect(json[:total_items]).to eq(3)
        expect(json[:total_price].to_f).to eq(210.0)
      end
    end

    context 'with no active items' do
      it 'returns zero totals' do
        get '/api/v1/carts/summary', headers: headers, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:total_items]).to eq(0)
        expect(json[:total_price]).to eq(0)
      end
    end

    context 'with deleted items only' do
      before { create(:cart, user: user, book: book, quantity: 2, is_deleted: true) }

      it 'excludes deleted items' do
        get '/api/v1/carts/summary', headers: headers, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:total_items]).to eq(0)
        expect(json[:total_price]).to eq(0)
      end
    end

    context 'authentication' do
      it 'fails without token' do
        get '/api/v1/carts/summary', as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH /api/v1/carts/:id/delete' do
    let!(:cart) { create(:cart, user: user, book: book, quantity: 1, is_deleted: false) }

    context 'with valid book_id' do
      it 'removes an active item' do
        patch "/api/v1/carts/#{book.id}/delete", headers: headers, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:success]).to be true
        expect(json[:message]).to eq('Item removed from cart.')
        expect(cart.reload.is_deleted).to be true
      end

      it 'restores a removed item' do
        cart.update(is_deleted: true)
        patch "/api/v1/carts/#{book.id}/delete", headers: headers, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:message]).to eq('Item restored from cart.')
        expect(cart.reload.is_deleted).to be false
      end

      it 'accepts nested parameters' do
        patch "/api/v1/carts/#{book.id}/delete", params: { cart: { book_id: book.id } }, headers: headers, as: :json
        expect(response).to have_http_status(:ok)
        expect(cart.reload.is_deleted).to be true
      end
    end

    context 'with invalid book_id' do

      it 'fails for non-existent cart item' do
        patch '/api/v1/carts/999/delete', headers: headers, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:success]).to be false
        expect(json[:message]).to eq('Item not found in cart')
      end
    end

    context 'authentication' do
      it 'fails without token' do
        patch "/api/v1/carts/#{book.id}/delete", as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/carts' do
    before { create_list(:cart, 3, user: user, book: book, quantity: 1, is_deleted: false) }

    context 'with pagination' do
      it 'returns paginated active cart items' do
        get '/api/v1/carts', params: { page: 1, per_page: 2 }, headers: headers, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:success]).to be true
        expect(json[:cart].length).to eq(2)
        expect(json[:pagination][:current_page]).to eq(1)
        expect(json[:pagination][:total_count]).to eq(3)
      end
    end

    context 'without pagination params' do
      it 'returns all active items' do
        get '/api/v1/carts', headers: headers, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:cart].length).to eq(3)
        expect(json[:total_cart_price].to_f).to eq(240.0)
      end
    end

    context 'with mixed active and deleted items' do
      before { user.carts.first.update(is_deleted: true) }

      it 'excludes deleted items' do
        get '/api/v1/carts', headers: headers, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:cart].length).to eq(2)
        expect(json[:total_cart_price].to_f).to eq(160.0)
      end
    end

    context 'authentication' do
      it 'fails without token' do
        get '/api/v1/carts', as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH /api/v1/carts/:id' do
    let!(:cart) { create(:cart, user: user, book: book, quantity: 1, is_deleted: false) }

    context 'with valid parameters' do
      it 'updates quantity successfully' do
        patch "/api/v1/carts/#{book.id}", params: { quantity: 3 }, headers: headers, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:success]).to be true
        expect(json[:message]).to eq('Quantity updated successfully.')
        expect(cart.reload.quantity).to eq(3)
      end
    end

    context 'with invalid parameters' do
      it 'fails with nil book_id' do
        patch "/api/v1/carts/0", params: { quantity: 2 }, headers: headers, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:message]).to eq('Invalid book_id or quantity.')
      end

      it 'fails with zero quantity' do
        patch "/api/v1/carts/#{book.id}", params: { quantity: 0 }, headers: headers, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:message]).to eq('Invalid book_id or quantity.')
      end

      it 'fails with insufficient stock' do
        patch "/api/v1/carts/#{book.id}", params: { quantity: 15 }, headers: headers, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:message]).to eq('Not enough stock available.')
      end

      it 'fails with non-existent cart item' do
        patch '/api/v1/carts/999', params: { quantity: 2 }, headers: headers, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:message]).to eq('Item not found in cart')
      end
    end

    context 'authentication' do
      it 'fails without token' do
        patch "/api/v1/carts/#{book.id}", params: { quantity: 2 }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end