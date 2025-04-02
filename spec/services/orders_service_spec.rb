# spec/services/orders_service_spec.rb
require 'rails_helper'

RSpec.describe OrdersService, type: :service do
  let(:user) { create(:user) }
  let(:book) { create(:book, discounted_price: 200, book_mrp: 250) }
  let(:address) { create(:address, user: user) }

  describe '.fetch_user_orders' do
    it 'returns all user orders' do
      create(:order, user: user, book: book, address: address)
      result = OrdersService.fetch_user_orders(user)
      expect(result[:success]).to be true
      expect(result[:orders].length).to eq(1)
    end
  end

  describe '.fetch_order' do
    let(:order) { create(:order, user: user, book: book, address: address) }

    it 'returns the order' do
      result = OrdersService.fetch_order(user, order.id)
      expect(result[:success]).to be true
      expect(result[:order].id).to eq(order.id)
    end

    it 'returns error for non-existent order' do
      result = OrdersService.fetch_order(user, 9999)
      expect(result[:success]).to be false
      expect(result[:message]).to eq("Order not found")
    end
  end

  describe '.create_order' do
    before do
      # Setup cart item for all tests since create_order requires it
      create(:cart, user: user, book: book, quantity: 2)
    end

    context 'when all parameters are valid including address_id' do
      let(:order_params) { { book_id: book.id, quantity: 2, address_id: address.id } }

      it 'creates an order successfully' do
        result = OrdersService.create_order(user, order_params)
        expect(result[:success]).to be true
        expect(result[:message]).to eq("Order placed successfully")
        expect(result[:orders].first.book_id).to eq(book.id)
        expect(result[:orders].first.quantity).to eq(2)
        expect(result[:orders].first.address_id).to eq(address.id)
        expect(result[:orders].first.total_price).to eq(400)
      end
    end

    context 'when book_id is nil or missing' do
      let(:order_params) { { quantity: 2, address_id: address.id } }

      it 'returns an error' do
        user.carts.destroy_all
        result = OrdersService.create_order(user, order_params)
        expect(result[:success]).to be false
        expect(result[:message]).to eq("Your cart is empty. Add items before placing an order.")
      end
    end

    context 'when book does not exist' do
      let(:order_params) { { book_id: book.id, quantity: 2, address_id: address.id } }

      it 'returns an error' do
        # Get the cart item and stub its book association to return nil
        cart_item = user.carts.first
        allow(cart_item).to receive(:book).and_return(nil)
        
        result = OrdersService.create_order(user, order_params)
        expect(result[:success]).to be false
        expect(result[:errors]).to include("Book must exist")
      end
    end

    context 'when address_id is invalid' do
      let(:order_params) { { book_id: book.id, quantity: 2, address_id: 9999 } }

      it 'returns an error' do
        result = OrdersService.create_order(user, order_params)
        expect(result[:success]).to be false
        expect(result[:message]).to eq("Address not found")
      end
    end

    context 'when quantity is zero or negative' do
      let(:order_params) { { book_id: book.id, quantity: 0, address_id: address.id } }

      it 'fails due to validation' do
        user.carts.destroy_all
        create(:cart, user: user, book: book, quantity: 0)
        result = OrdersService.create_order(user, order_params)
        expect(result[:success]).to be false
        expect(result[:errors]).to include("Quantity must be greater than 0")
      end
    end
  end

  describe '.update_order_status' do
    let(:order) { create(:order, user: user, book: book, address: address, status: "pending") }

    it 'updates the status' do
      result = OrdersService.update_order_status(user, order.id, "shipped")
      expect(result[:success]).to be true
      expect(result[:message]).to eq("Order status updated")
      expect(result[:order].status).to eq("shipped")
    end

    it 'returns error for invalid status' do
      result = OrdersService.update_order_status(user, order.id, "invalid")
      expect(result[:success]).to be false
      expect(result[:message]).to eq("Invalid status")
    end
  end

  describe '.cancel_order' do
    let(:order) { create(:order, user: user, book: book, address: address, status: "pending") }

    it 'cancels the order' do
      result = OrdersService.cancel_order(user, order.id)
      expect(result[:success]).to be true
      expect(result[:message]).to eq("Order cancelled successfully")
      expect(result[:order].status).to eq("cancelled")
    end

    it 'returns error if already cancelled' do
      order.update(status: "cancelled")
      result = OrdersService.cancel_order(user, order.id)
      expect(result[:success]).to be false
      expect(result[:message]).to eq("Order is already cancelled")
    end
  end
end