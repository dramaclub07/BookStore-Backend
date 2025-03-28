require 'rails_helper'

RSpec.describe 'Orders API', type: :request do
  let(:user) { create(:user) }
  let(:token) { JwtService.encode_access_token(user_id: user.id) }
  let(:headers) { { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' } }

  def json
    JSON.parse(response.body, symbolize_names: true)
  rescue JSON::ParserError
    puts "Failed to parse JSON response: #{response.body}"
    {}
  end

  describe 'GET /api/v1/orders' do
    context 'when user is authenticated' do
      it 'returns all orders of the logged-in user' do
        order = create(:order, user: user)
        get '/api/v1/orders', headers: headers
        expect(response).to have_http_status(:ok)
        expect(json[:success]).to be true
        expect(json[:orders].map { |o| o[:id] }).to include(order.id)
      end

      it 'returns an empty array when user has no orders' do
        get '/api/v1/orders', headers: headers
        expect(response).to have_http_status(:ok)
        expect(json[:success]).to be true
        expect(json[:orders]).to eq([])
      end
    end

    context 'when authentication fails' do
      it 'returns unauthorized when no token is provided' do
        get '/api/v1/orders'
        expect(response).to have_http_status(:unauthorized)
        expect(json[:success]).to be false
        expect(json[:message]).to eq('Unauthorized - Missing token')
      end

      it 'returns unauthorized when token is invalid' do
        get '/api/v1/orders', headers: { 'Authorization' => 'Bearer invalid.token.here' }
        expect(response).to have_http_status(:unauthorized)
        expect(json[:success]).to be false
        expect(json[:message]).to eq('Unauthorized - Invalid or expired token')
      end

      it 'returns unauthorized when user does not exist' do
        non_existent_token = JwtService.encode_access_token(user_id: 9999)
        get '/api/v1/orders', headers: { 'Authorization' => "Bearer #{non_existent_token}" }
        expect(response).to have_http_status(:unauthorized)
        expect(json[:success]).to be false
        expect(json[:message]).to eq('Unauthorized - User not found')
      end
    end
  end

  describe 'POST /api/v1/orders' do
    context 'when creating from params' do
      let(:book) { create(:book) }
      let(:address) { create(:address, user: user) }

      context 'when user is authenticated' do
        it 'creates an order successfully' do
          post '/api/v1/orders', params: { order: { book_id: book.id, address_id: address.id, quantity: 2 } }.to_json, headers: headers
          expect(response).to have_http_status(:created)
          expect(json[:success]).to be true
          expect(json[:order][:book_id]).to eq(book.id)
          expect(json[:order][:address_id]).to eq(address.id)
        end

        it 'returns an error when book_id is missing' do
          post '/api/v1/orders', params: { order: { address_id: address.id } }.to_json, headers: headers
          expect(response).to have_http_status(:unprocessable_entity)
          expect(json[:success]).to be false
          expect(json[:message]).to eq('Book must be provided')
        end

        it 'returns an error when book_id is invalid' do
          post '/api/v1/orders', params: { order: { book_id: 999, address_id: address.id } }.to_json, headers: headers
          expect(response).to have_http_status(:unprocessable_entity)
          expect(json[:success]).to be false
          expect(json[:message]).to eq('Book not found')
        end

        it 'returns an error when address_id is missing' do
          post '/api/v1/orders', params: { order: { book_id: book.id } }.to_json, headers: headers
          expect(response).to have_http_status(:unprocessable_entity)
          expect(json[:success]).to be false
          expect(json[:message]).to eq('Address must be provided')
        end

        it 'returns an error when address_id is invalid' do
          post '/api/v1/orders', params: { order: { book_id: book.id, address_id: 999 } }.to_json, headers: headers
          expect(response).to have_http_status(:unprocessable_entity)
          expect(json[:success]).to be false
          expect(json[:message]).to eq('Address not found')
        end

        it 'returns an error when order fails to save' do
          allow_any_instance_of(Order).to receive(:save).and_return(false)
          allow_any_instance_of(Order).to receive(:errors).and_return(double(full_messages: ['Invalid order']))
          post '/api/v1/orders', params: { order: { book_id: book.id, address_id: address.id } }.to_json, headers: headers
          expect(response).to have_http_status(:unprocessable_entity)
          expect(json[:success]).to be false
          expect(json[:errors]).to eq(['Invalid order'])
        end
      end

      context 'when user is not authenticated' do
        it 'returns an unauthorized error' do
          post '/api/v1/orders', params: { order: { book_id: book.id, address_id: address.id } }.to_json
          expect(response).to have_http_status(:unauthorized)
          expect(json[:success]).to be false
          expect(json[:message]).to eq('Unauthorized - Missing token')
        end
      end
    end

    context 'when creating from cart' do
      let(:book) { create(:book) }
      let(:address) { create(:address, user: user) }
      let(:cart) { create(:cart, user: user, book: book) }

      context 'when user is authenticated' do
        it 'creates orders from cart items successfully' do
          cart # Ensure cart is created
          post '/api/v1/orders', params: { address_id: address.id }.to_json, headers: headers
          expect(response).to have_http_status(:created)
          expect(json[:success]).to be true
          expect(json[:orders].first[:book_id]).to eq(book.id)
        end

        it 'returns an error when cart is empty' do
          post '/api/v1/orders', params: { address_id: address.id }.to_json, headers: headers
          expect(response).to have_http_status(:unprocessable_entity)
          expect(json[:success]).to be false
          expect(json[:message]).to eq('Your cart is empty. Add items before placing an order.')
        end

        it 'returns an error when address_id is missing' do
          cart # Ensure cart is created
          post '/api/v1/orders', params: {}.to_json, headers: headers
          expect(response).to have_http_status(:unprocessable_entity)
          expect(json[:success]).to be false
          expect(json[:message]).to eq('Address must be provided')
        end

        it 'returns an error when address_id is invalid' do
          cart # Ensure cart is created
          post '/api/v1/orders', params: { address_id: 999 }.to_json, headers: headers
          expect(response).to have_http_status(:unprocessable_entity)
          expect(json[:success]).to be false
          expect(json[:message]).to eq('Address not found')
        end

        it 'returns an error when an order fails to save' do
          cart # Ensure cart is created
          allow_any_instance_of(Order).to receive(:save).and_return(false)
          allow_any_instance_of(Order).to receive(:errors).and_return(double(full_messages: ['Invalid order']))
          post '/api/v1/orders', params: { address_id: address.id }.to_json, headers: headers
          expect(response).to have_http_status(:unprocessable_entity)
          expect(json[:success]).to be false
          expect(json[:errors]).to eq(['Invalid order'])
        end
      end

      context 'when user is not authenticated' do
        it 'returns an unauthorized error' do
          post '/api/v1/orders', params: { address_id: address.id }.to_json
          expect(response).to have_http_status(:unauthorized)
          expect(json[:success]).to be false
          expect(json[:message]).to eq('Unauthorized - Missing token')
        end
      end
    end
  end

  describe 'GET /api/v1/orders/:id' do
    context 'when user is authenticated' do
      let(:order) { create(:order, user: user) }

      it 'returns the order details' do
        get "/api/v1/orders/#{order.id}", headers: headers
        expect(response).to have_http_status(:ok)
        expect(json[:success]).to be true
        expect(json[:order][:id]).to eq(order.id)
      end

      it 'returns an error when order is not found' do
        get '/api/v1/orders/999', headers: headers
        expect(response).to have_http_status(:not_found)
        expect(json[:success]).to be false
        expect(json[:message]).to eq('Order not found')
      end
    end

    context 'when user is not authenticated' do
      it 'returns an unauthorized error' do
        get '/api/v1/orders/1'
        expect(response).to have_http_status(:unauthorized)
        expect(json[:success]).to be false
        expect(json[:message]).to eq('Unauthorized - Missing token')
      end
    end
  end

  describe 'PATCH /api/v1/orders/:id/cancel' do
    context 'when user is authenticated' do
      let(:order) { create(:order, user: user, status: 'pending') }

      it 'cancels an order successfully' do
        patch "/api/v1/orders/#{order.id}/cancel", headers: headers
        expect(response).to have_http_status(:ok)
        expect(json[:success]).to be true
        expect(json[:message]).to eq('Order cancelled successfully')
        expect(order.reload.status).to eq('cancelled')
      end

      it 'returns an error when order is already cancelled' do
        order.update(status: 'cancelled')
        patch "/api/v1/orders/#{order.id}/cancel", headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json[:success]).to be false
        expect(json[:message]).to eq('Order is already cancelled')
      end

      it 'returns an error when order is not found' do
        patch '/api/v1/orders/999/cancel', headers: headers
        expect(response).to have_http_status(:not_found)
        expect(json[:success]).to be false
        expect(json[:message]).to eq('Order not found')
      end
    end

    context 'when user is not authenticated' do
      it 'returns an unauthorized error' do
        patch '/api/v1/orders/1/cancel'
        expect(response).to have_http_status(:unauthorized)
        expect(json[:success]).to be false
        expect(json[:message]).to eq('Unauthorized - Missing token')
      end
    end
  end

  describe 'PATCH /api/v1/orders/:id/update' do
    context 'when user is authenticated' do
      let(:order) { create(:order, user: user, status: 'pending') }

      it 'updates the order status successfully' do
        patch "/api/v1/orders/#{order.id}/update", params: { status: 'shipped' }.to_json, headers: headers
        expect(response).to have_http_status(:ok)
        expect(json[:success]).to be true
        expect(json[:message]).to eq('Order status updated')
        expect(order.reload.status).to eq('shipped')
      end

      it 'returns an error when status is invalid' do
        patch "/api/v1/orders/#{order.id}/update", params: { status: 'invalid' }.to_json, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json[:success]).to be false
        expect(json[:message]).to eq('Invalid status')
      end

      it 'returns an error when order is not found' do
        patch '/api/v1/orders/999/update', params: { status: 'shipped' }.to_json, headers: headers
        expect(response).to have_http_status(:not_found)
        expect(json[:success]).to be false
        expect(json[:message]).to eq('Order not found')
      end
    end

    context 'when user is not authenticated' do
      it 'returns an unauthorized error' do
        patch '/api/v1/orders/1/update', params: { status: 'shipped' }.to_json
        expect(response).to have_http_status(:unauthorized)
        expect(json[:success]).to be false
        expect(json[:message]).to eq('Unauthorized - Missing token')
      end
    end
  end
end