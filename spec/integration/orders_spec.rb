require 'rails_helper'

RSpec.describe "Api::V1::Orders Integration", type: :request do
  let(:user) { create(:user) }
  let(:book) { create(:book, discounted_price: 200, book_mrp: 250) }
  let(:address) { create(:address, user: user) }
  let(:token) { JwtService.encode_access_token(user_id: user.id) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  describe "GET /api/v1/orders" do
    it "returns all orders for the authenticated user" do
      create(:order, user: user, book: book)
      get "/api/v1/orders", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["orders"].length).to eq(1)
    end
  end

  describe "POST /api/v1/orders" do
    context "with valid order params" do
      let(:params) { { order: { book_id: book.id, quantity: 2, address_id: address.id } } }
      it "creates an order successfully" do
        post "/api/v1/orders", params: params, headers: headers
        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
        expect(json["orders"].first["quantity"]).to eq(2)
        expect(json["orders"].first["total_price"].to_i).to eq(400) # 200 * 2
      end
    end

    context "from cart with address_id" do
      let(:cart_item) { create(:cart, user: user, book: book, quantity: 1, is_deleted: false) }
      let(:params) { { address_id: address.id } }
      it "creates orders from cart" do
        cart_item
        post "/api/v1/orders", params: params, headers: headers
        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
        expect(json["orders"].length).to eq(1)
        expect(json["orders"][0]["total_price"].to_i).to eq(200)
      end
    end

    context "with invalid parameters" do
      let(:params) { {} }
      it "returns an error" do
        post "/api/v1/orders", params: params, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["success"]).to be false
        expect(json["message"]).to eq("Invalid parameters")
      end
    end

    context "with invalid book_id" do
      let(:params) { { order: { book_id: 9999, quantity: 2, address_id: address.id } } }
      it "returns an error" do
        post "/api/v1/orders", params: params, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["success"]).to be false
        expect(json["message"]).to eq("Book not found")
      end
    end

    context "with invalid address_id" do
      let(:params) { { order: { book_id: book.id, quantity: 2, address_id: 9999 } } }
      it "returns an error" do
        post "/api/v1/orders", params: params, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["success"]).to be false
        expect(json["message"]).to eq("Address not found")
      end
    end
  end

  describe "GET /api/v1/orders/:id" do
    let(:order) { create(:order, user: user, book: book, quantity: 1) }
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
      expect(json["errors"]).to eq(["Order not found"])
    end
  end

  describe "PATCH /api/v1/orders/:id" do
    let(:order) { create(:order, user: user, book: book, status: "pending") }
    it "updates the order status" do
      patch "/api/v1/orders/#{order.id}", params: { status: "shipped" }, headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["order"]["status"]).to eq("shipped")
    end

    it "returns an error for invalid order id" do
      patch "/api/v1/orders/9999", params: { status: "shipped" }, headers: headers
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["errors"]).to eq(["Order not found"])
    end

    it "returns an error for invalid status" do
      patch "/api/v1/orders/#{order.id}", params: { status: "invalid" }, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["errors"]).to eq(["Invalid status"])
    end
  end

  describe "DELETE /api/v1/orders/:id" do
    let(:order) { create(:order, user: user, book: book, status: "pending") }
    it "cancels the order" do
      delete "/api/v1/orders/#{order.id}", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["order"]["status"]).to eq("cancelled")
    end

    it "returns an error for invalid order id" do
      delete "/api/v1/orders/9999", headers: headers
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["errors"]).to eq(["Order not found"])
    end

    it "returns an error if already cancelled" do
      order.update(status: "cancelled")
      delete "/api/v1/orders/#{order.id}", headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["errors"]).to eq(["Order is already cancelled"])
    end
  end

  describe "authentication" do
    it "returns unauthorized without token" do
      get "/api/v1/orders"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # Mock external dependencies if needed
  before do
    allow(EmailProducer).to receive(:publish_email)
  end
end