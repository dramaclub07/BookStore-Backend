require 'rails_helper'

RSpec.describe OrdersService, type: :service do
  let(:user) { create(:user) }
  let(:book) { create(:book, discounted_price: 200, book_mrp: 250) }
  let(:address) { create(:address, user: user) }

  describe '.create_order' do
    context 'when all parameters are valid including address_id' do
      let(:order_params) { { book_id: book.id, quantity: 2, address_id: address.id } }

      it 'creates an order successfully' do
        result = OrdersService.create_order(user, order_params)
        expect(result[:success]).to be true
        expect(result[:order].book_id).to eq(book.id)
        expect(result[:order].quantity).to eq(2)
        expect(result[:order].address_id).to eq(address.id)
        expect(result[:order].total_price).to eq(400)
      end
    end

    context 'when only book_id is provided' do
      let(:order_params) { { book_id: book.id } }

      it 'creates an order with default quantity and no address' do
        result = OrdersService.create_order(user, order_params)
        expect(result[:success]).to be true
        expect(result[:order].quantity).to eq(1)
        expect(result[:order].address_id).to be_nil
        expect(result[:order].total_price).to eq(200)
      end
    end

    context 'when book_id is nil or missing' do
      let(:order_params) { { quantity: 2, address_id: address.id } }

      it 'returns an error' do
        result = OrdersService.create_order(user, order_params)
        expect(result[:success]).to be false
        expect(result[:errors]).to eq(["Book must be provided"])
      end
    end

    context 'when book does not exist' do
      let(:order_params) { { book_id: 9999, quantity: 2, address_id: address.id } }

      it 'returns an error' do
        result = OrdersService.create_order(user, order_params)
        expect(result[:success]).to be false
        expect(result[:errors]).to eq(["Book not found"])
      end
    end

    context 'when address_id is invalid' do
      let(:order_params) { { book_id: book.id, quantity: 2, address_id: 9999 } }

      it 'returns an error' do
        result = OrdersService.create_order(user, order_params)
        expect(result[:success]).to be false
        expect(result[:errors]).to eq(["Address not found"])
      end
    end

    context 'when quantity is zero or negative' do
      let(:order_params) { { book_id: book.id, quantity: 0, address_id: address.id } }

      it 'fails due to validation' do
        result = OrdersService.create_order(user, order_params)
        expect(result[:success]).to be false
        expect(result[:errors]).to include("Quantity must be greater than 0")
      end
    end
  end

  describe '.fetch_all_orders' do
    it 'returns all user orders' do
      create(:order, user: user, book: book)
      result = OrdersService.fetch_all_orders(user)
      expect(result[:success]).to be true
      expect(result[:orders].length).to eq(1)
    end
  end

  describe '.fetch_order' do
    let(:order) { create(:order, user: user, book: book) }

    it 'returns the order' do
      result = OrdersService.fetch_order(user, order.id)
      expect(result[:success]).to be true
      expect(result[:order].id).to eq(order.id)
    end

    it 'returns error for non-existent order' do
      result = OrdersService.fetch_order(user, 9999)
      expect(result[:success]).to be false
      expect(result[:errors]).to eq(["Order not found"])
    end
  end

  describe '.update_order_status' do
    let(:order) { create(:order, user: user, book: book, status: "pending") }

    it 'updates the status' do
      result = OrdersService.update_order_status(user, order.id, "shipped")
      expect(result[:success]).to be true
      expect(result[:order].status).to eq("shipped")
    end

    it 'returns error for invalid status' do
      result = OrdersService.update_order_status(user, order.id, "invalid")
      expect(result[:success]).to be false
      expect(result[:errors]).to eq(["Invalid status"])
    end
  end

  describe '.cancel_order' do
    let(:order) { create(:order, user: user, book: book, status: "pending") }

    it 'cancels the order' do
      result = OrdersService.cancel_order(user, order.id)
      expect(result[:success]).to be true
      expect(result[:order].status).to eq("cancelled")
    end

    it 'returns error if already cancelled' do
      order.update(status: "cancelled")
      result = OrdersService.cancel_order(user, order.id)
      expect(result[:success]).to be false
      expect(result[:errors]).to eq(["Order is already cancelled"])
    end
  end
end