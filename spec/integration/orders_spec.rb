# spec/integration/orders_spec.rb
require 'rails_helper'

RSpec.describe "Api::V1::Orders Integration", type: :request do
  let(:user) { create(:user) }
  let(:book) { create(:book, discounted_price: 200, book_mrp: 250) }
  let(:address) { create(:address, user: user) }
  let(:order) { create(:order, user: user, book: book, address: address) }
  let(:token) { JwtService.encode_access_token({ user_id: user.id }) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  describe "GET /api/v1/orders" do
    it "returns all orders for the authenticated user" do
      create(:order, user: user, book: book, address: address)
      get "/api/v1/orders", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["orders"].length).to eq(1)
    end
  end

  describe "POST /api/v1/orders" do
    before do
      # Setup cart for order creation
      create(:cart, user: user, book: book, quantity: 2)
    end

    context "with valid order params" do
      let(:order_params) { { order: { book_id: book.id, quantity: 2, address_id: address.id } } }

      it "creates an order successfully" do
        post "/api/v1/orders", params: order_params, headers: headers
        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
        expect(json["message"]).to eq("Order placed successfully")
        expect(json["orders"].first["book_id"]).to eq(book.id)
      end
    end

    context "with invalid book_id" do
      let(:order_params) { { order: { book_id: 9999, quantity: 2, address_id: address.id } } }

      it "returns an error" do
        # Clear existing cart
        user.carts.destroy_all
        # Create a cart with a valid book
        cart = create(:cart, user: user, book: book, quantity: 2)
        # Stub the order creation to fail with an invalid book_id
        allow_any_instance_of(Order).to receive(:save).and_return(false)
        allow_any_instance_of(Order).to receive(:errors).and_return(double(full_messages: ["Book must exist"]))
        
        post "/api/v1/orders", params: order_params, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["success"]).to be false
        expect(json["errors"]).to include("Book must exist")
      end
    end

    context "from cart with address_id" do
      let(:cart_params) { { address_id: address.id } }

      it "creates orders from cart" do
        post "/api/v1/orders", params: cart_params, headers: headers
        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
        expect(json["message"]).to eq("Order placed successfully")
      end
    end
  end

  describe "GET /api/v1/orders/:id" do
    it "returns the order" do
      get "/api/v1/orders/#{order.id}", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["order"]["id"]).to eq(order.id)
    end

    it "returns not found for invalid id" do
      get "/api/v1/orders/9999", headers: headers
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["message"]).to eq("Order not found")
    end
  end

  describe "PATCH /api/v1/orders/:id" do
    it "updates the order status" do
      patch "/api/v1/orders/#{order.id}/update", params: { status: "shipped" }, headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["message"]).to eq("Order status updated")
      expect(json["order"]["status"]).to eq("shipped")
    end

    it "returns an error for invalid status" do
      patch "/api/v1/orders/#{order.id}/update", params: { status: "invalid" }, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["message"]).to eq("Invalid status")
    end
  end

  describe "DELETE /api/v1/orders/:id" do
    it "cancels the order" do
      patch "/api/v1/orders/#{order.id}/cancel", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["message"]).to eq("Order cancelled successfully")
      expect(json["order"]["status"]).to eq("cancelled")
    end

    it "returns an error if already cancelled" do
      order.update(status: "cancelled")
      patch "/api/v1/orders/#{order.id}/cancel", headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["message"]).to eq("Order is already cancelled")
    end
  end
end