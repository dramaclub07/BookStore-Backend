require 'rails_helper'

RSpec.describe "Orders API", type: :request do
  let(:user) { create(:user) }
  let(:book) { create(:book) }
  let(:address) { create(:address, user: user) }
  let(:token) { JwtService.encode(user_id: user.id) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }
  let(:invalid_headers) { { "Authorization" => "Bearer invalid_token" } }
  let(:order) { create(:order, user: user, book: book, address: address) }

  describe "GET /api/v1/orders" do
    context "when user is authenticated" do
      it "returns all orders of the logged-in user" do
        create_list(:order, 3, user: user, address: address)
        get "/api/v1/orders", headers: headers
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["success"]).to be true
        expect(JSON.parse(response.body)["orders"].size).to eq(3)
      end
    end

    context "when user is not authenticated" do
      it "returns an unauthorized error" do
        get "/api/v1/orders", headers: {}
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/orders" do
    let(:valid_params) do
      {
        order: {
          book_id: book.id,
          quantity: 2,
          address_id: address.id,
          price_at_purchase: book.discounted_price || book.book_mrp || 10.99,
          total_price: (book.discounted_price || book.book_mrp || 10.99) * 2,
          status: "pending"
        }
      }
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
      end

      it "returns an error when book_id is missing" do
        invalid_params = { order: { quantity: 2, address_id: address.id } }
        post "/api/v1/orders", params: invalid_params, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["success"]).to be false
        expect(JSON.parse(response.body)["errors"]).to include("Book must be provided")
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
    end

    context "when user is not authenticated" do
      it "returns an unauthorized error" do
        post "/api/v1/orders", params: valid_params, headers: {}
        expect(response).to have_http_status(:unauthorized)
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
    end

    context "when user is not authenticated" do
      it "returns an unauthorized error" do
        get "/api/v1/orders/#{order.id}", headers: {}
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
    end

    context "when user is not authenticated" do
      it "returns an unauthorized error" do
        patch "/api/v1/orders/#{order.id}/cancel", headers: {}
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
    end

    context "when user is not authenticated" do
      it "returns an unauthorized error" do
        patch "/api/v1/orders/#{order.id}/update_status", params: { status: "shipped" }, headers: {}
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end