require 'rails_helper'

RSpec.describe "Orders API", type: :request do
  let(:user) { create(:user) }
  let(:book) { create(:book, discounted_price: 200, book_mrp: 250) }
  let(:address) { create(:address, user: user) }
  let(:token) { JwtService.encode(user_id: user.id) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }
  let(:invalid_token_headers) { { "Authorization" => "Bearer invalid_token" } }
  let(:no_token_headers) { {} }
  let(:order) { create(:order, user: user, book: book, address: address) }
  let(:cart_item) { create(:cart, user: user, book: book, quantity: 2) }

  describe "GET /api/v1/orders" do
    context "when user is authenticated" do
      it "returns all orders of the logged-in user" do
        create_list(:order, 3, user: user, address: address)
        get "/api/v1/orders", headers: headers
        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        expect(response_body["success"]).to be true
        expect(response_body["orders"].size).to eq(3)
      end

      it "returns an empty array when user has no orders" do
        get "/api/v1/orders", headers: headers
        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        expect(response_body["success"]).to be true
        expect(response_body["orders"]).to eq([])
      end
    end

    context "when authentication fails" do
      it "returns unauthorized when no token is provided" do
        get "/api/v1/orders", headers: no_token_headers
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns unauthorized when token is invalid" do
        get "/api/v1/orders", headers: invalid_token_headers
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns unauthorized when user does not exist" do
        non_existent_token = JwtService.encode(user_id: 9999)
        headers_with_bad_user = { "Authorization" => "Bearer #{non_existent_token}" }
        get "/api/v1/orders", headers: headers_with_bad_user
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/orders" do
    context "when creating from params" do
      let(:valid_params) do
        { order: { book_id: book.id, quantity: 2, address_id: address.id } }
      end

      context "when user is authenticated" do
        it "creates an order successfully" do
          post "/api/v1/orders", params: valid_params, headers: headers
          expect(response).to have_http_status(:created)
          response_body = JSON.parse(response.body)
          expect(response_body["success"]).to be true
          expect(response_body["order"]["book_id"]).to eq(book.id)
          expect(response_body["order"]["quantity"]).to eq(2)
          expect(response_body["order"]["address_id"]).to eq(address.id)
          expect(response_body["order"]["status"]).to eq("pending")
          expect(response_body["order"]["total_price"]).to eq("400.0")
        end

        it "returns an error when book_id is missing" do
          invalid_params = { order: { quantity: 2, address_id: address.id } }
          post "/api/v1/orders", params: invalid_params, headers: headers
          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)["success"]).to be false
          expect(JSON.parse(response.body)["errors"]).to include("Book must be provided")
        end

        it "returns an error when book_id is invalid" do
          invalid_params = { order: { book_id: 9999, quantity: 2, address_id: address.id } }
          post "/api/v1/orders", params: invalid_params, headers: headers
          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)["success"]).to be false
          expect(JSON.parse(response.body)["errors"]).to include("Book not found")
        end

        it "returns an error when address_id is missing" do
          invalid_params = { order: { book_id: book.id, quantity: 2 } }
          post "/api/v1/orders", params: invalid_params, headers: headers
          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)["success"]).to be false
          expect(JSON.parse(response.body)["errors"]).to include("Address must be provided")
        end

        it "returns an error when address_id is invalid" do
          invalid_params = { order: { book_id: book.id, quantity: 2, address_id: 9999 } }
          post "/api/v1/orders", params: invalid_params, headers: headers
          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)["success"]).to be false
          expect(JSON.parse(response.body)["errors"]).to include("Address not found")
        end

        it "returns an error when order fails to save" do
          invalid_params = { order: { book_id: book.id, quantity: -1, address_id: address.id } }
          post "/api/v1/orders", params: invalid_params, headers: headers
          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)["success"]).to be false
          expect(JSON.parse(response.body)["errors"]).to include("Quantity must be greater than 0")
        end
      end

      context "when user is not authenticated" do
        it "returns an unauthorized error" do
          post "/api/v1/orders", params: valid_params, headers: no_token_headers
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    context "when creating from cart" do
      let(:cart_params) { { cart_items: true, address_id: address.id } }

      before { cart_item } # Ensure cart item is created

      context "when user is authenticated" do
        it "creates orders from cart items successfully" do
          post "/api/v1/orders", params: cart_params, headers: headers
          expect(response).to have_http_status(:created)
          response_body = JSON.parse(response.body)
          expect(response_body["success"]).to be true
          expect(response_body["message"]).to eq("Order placed successfully")
          expect(response_body["orders"].size).to eq(1)
          expect(response_body["orders"][0]["book_id"]).to eq(book.id)
          expect(response_body["orders"][0]["quantity"]).to eq(2)
          expect(response_body["orders"][0]["address_id"]).to eq(address.id)
          expect(response_body["orders"][0]["total_price"]).to eq("400.0")
          expect(user.carts.active.count).to eq(0)
        end

        it "returns an error when cart is empty" do
          user.carts.destroy_all
          post "/api/v1/orders", params: cart_params, headers: headers
          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)["success"]).to be false
          expect(JSON.parse(response.body)["errors"]).to include("Your cart is empty. Add items before placing an order.")
        end

        it "returns an error when address_id is missing" do
          invalid_cart_params = { cart_items: true }
          post "/api/v1/orders", params: invalid_cart_params, headers: headers
          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)["success"]).to be false
          expect(JSON.parse(response.body)["errors"]).to include("Address must be provided")
        end

        it "returns an error when address_id is invalid" do
          invalid_cart_params = { cart_items: true, address_id: 9999 }
          post "/api/v1/orders", params: invalid_cart_params, headers: headers
          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)["success"]).to be false
          expect(JSON.parse(response.body)["errors"]).to include("Address not found")
        end

        it "returns an error when an order fails to save" do
          allow_any_instance_of(Order).to receive(:save).and_return(false)
          allow_any_instance_of(Order).to receive(:errors).and_return(double(full_messages: ["Invalid order"]))
          post "/api/v1/orders", params: cart_params, headers: headers
          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)["success"]).to be false
          expect(JSON.parse(response.body)["errors"]).to include("Invalid order")
        end
      end

      context "when user is not authenticated" do
        it "returns an unauthorized error" do
          post "/api/v1/orders", params: cart_params, headers: no_token_headers
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end
  end

  describe "GET /api/v1/orders/:id" do
    context "when user is authenticated" do
      it "returns the order details" do
        get "/api/v1/orders/#{order.id}", headers: headers
        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        expect(response_body["success"]).to be true
        expect(response_body["order"]["id"]).to eq(order.id)
      end

      it "returns an error when order is not found" do
        get "/api/v1/orders/9999", headers: headers
        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)["success"]).to be false
        expect(JSON.parse(response.body)["error"]).to eq("Order not found")
      end
    end

    context "when user is not authenticated" do
      it "returns an unauthorized error" do
        get "/api/v1/orders/#{order.id}", headers: no_token_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/orders/:id/cancel" do
    context "when user is authenticated" do
      it "cancels an order successfully" do
        patch "/api/v1/orders/#{order.id}/cancel", headers: headers
        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        expect(response_body["success"]).to be true
        expect(response_body["message"]).to eq("Order cancelled successfully")
        expect(response_body["order"]["status"]).to eq("cancelled")
      end

      it "returns an error when order is already cancelled" do
        order.update(status: "cancelled")
        patch "/api/v1/orders/#{order.id}/cancel", headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["success"]).to be false
        expect(JSON.parse(response.body)["error"]).to eq("Order is already cancelled")
      end

      it "returns an error when order is not found" do
        patch "/api/v1/orders/9999/cancel", headers: headers
        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)["success"]).to be false
        expect(JSON.parse(response.body)["error"]).to eq("Order not found")
      end
    end

    context "when user is not authenticated" do
      it "returns an unauthorized error" do
        patch "/api/v1/orders/#{order.id}/cancel", headers: no_token_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/orders/:id/update_status" do
    context "when user is authenticated" do
      it "updates the order status successfully" do
        patch "/api/v1/orders/#{order.id}/update_status", params: { status: "shipped" }, headers: headers
        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        expect(response_body["success"]).to be true
        expect(response_body["message"]).to eq("Order status updated")
        expect(response_body["order"]["status"]).to eq("shipped")
      end

      it "returns an error when status is invalid" do
        patch "/api/v1/orders/#{order.id}/update_status", params: { status: "invalid" }, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["success"]).to be false
        expect(JSON.parse(response.body)["error"]).to eq("Invalid status")
      end

      it "returns an error when order is not found" do
        patch "/api/v1/orders/9999/update_status", params: { status: "shipped" }, headers: headers
        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)["success"]).to be false
        expect(JSON.parse(response.body)["error"]).to eq("Order not found")
      end
    end

    context "when user is not authenticated" do
      it "returns an unauthorized error" do
        patch "/api/v1/orders/#{order.id}/update_status", params: { status: "shipped" }, headers: no_token_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end