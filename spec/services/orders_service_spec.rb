require 'rails_helper'

RSpec.describe OrdersService, type: :service do
  let(:user) { create(:user) }
  let(:book) { create(:book, discounted_price: 200, book_mrp: 250) }
  let(:address) { create(:address, user: user) }
  let(:cart_item) { create(:cart, user: user, book: book, quantity: 2, is_deleted: false) }

  describe '.fetch_all_orders' do
    it 'returns all orders for the user' do
      order = create(:order, user: user, book: book)
      result = OrdersService.fetch_all_orders(user)
      expect(result[:success]).to be true
      expect(result[:orders]).to eq([order])
    end
  end

  describe '.create_order' do
    context 'when address_id is missing' do
      let(:params) { { book_id: book.id, quantity: 1 } }
      it 'returns an error' do
        result = OrdersService.create_order(user, params)
        expect(result[:success]).to be false
        expect(result[:message]).to eq("Address must be provided")
      end
    end

    context 'when address_id is invalid' do
      let(:params) { { book_id: book.id, quantity: 1, address_id: 9999 } }
      it 'returns an error' do
        result = OrdersService.create_order(user, params)
        expect(result[:success]).to be false
        expect(result[:message]).to eq("Address not found")
      end
    end

    context 'when cart is empty and order is created directly' do
      let(:params) { { book_id: book.id, quantity: 1, address_id: address.id } }
      it 'creates an order successfully' do
        result = OrdersService.create_order(user, params)
        expect(result[:success]).to be true
        expect(result[:message]).to eq("Order placed successfully")
        expect(result[:orders].length).to eq(1)
        expect(result[:orders].first.total_price).to eq(200)
      end
    end

    context 'with existing cart items' do
      let(:params) { { book_id: book.id, quantity: 1, address_id: address.id } }
      it 'creates an order and clears cart' do
        cart_item
        expect(user.carts.active.count).to eq(1)
        result = OrdersService.create_order(user, params)
        expect(result[:success]).to be true
        expect(user.carts.active.count).to eq(0)
        expect(EmailProducer).to have_received(:publish_email).with("order_confirmation_email", hash_including(user_id: user.id))
      end
    end

    context 'when order creation fails' do
      let(:params) { { book_id: book.id, quantity: 0, address_id: address.id } }
      it 'returns validation errors' do
        result = OrdersService.create_order(user, params)
        expect(result[:success]).to be false
        expect(result[:errors]).to be_present
        expect(result[:errors]).to include("Quantity must be greater than 0")
      end
    end

    context 'when book_id is invalid' do
      let(:params) { { book_id: 9999, quantity: 1, address_id: address.id } }
      it 'returns an error' do
        result = OrdersService.create_order(user, params)
        expect(result[:success]).to be false
        expect(result[:message]).to eq("Book not found")
      end
    end
  end

  describe '.create_order_from_cart' do
    context 'when cart is empty' do
      it 'returns an error' do
        result = OrdersService.create_order_from_cart(user, address.id)
        expect(result[:success]).to be false
        expect(result[:errors]).to eq(["Your cart is empty. Add items before placing an order."])
      end
    end

    context 'when address_id is missing' do
      it 'returns an error' do
        cart_item
        result = OrdersService.create_order_from_cart(user, nil)
        expect(result[:success]).to be false
        expect(result[:errors]).to eq(["Address must be provided"])
      end
    end

    context 'when address_id is invalid' do
      it 'returns an error' do
        cart_item
        result = OrdersService.create_order_from_cart(user, 9999)
        expect(result[:success]).to be false
        expect(result[:errors]).to eq(["Address not found"])
      end
    end

    context 'with valid cart and address' do
      it 'creates orders and clears cart' do
        cart_item
        expect(user.carts.active.count).to eq(1)
        result = OrdersService.create_order_from_cart(user, address.id)
        expect(result[:success]).to be true
        expect(result[:message]).to eq("Orders created successfully from cart")
        expect(result[:orders].length).to eq(1)
        expect(result[:orders].first.total_price).to eq(400)
        expect(user.carts.active.count).to eq(0)
        expect(EmailProducer).to have_received(:publish_email).with("order_confirmation_email", hash_including(user_id: user.id))
      end
    end

    context 'when order creation fails in transaction' do
      it 'rolls back and returns errors' do
        cart_item
        # Create an invalid order with validation errors
        invalid_order = Order.new(quantity: 0, book_id: book.id, address_id: address.id, user_id: user.id)
        invalid_order.valid? # Trigger validation to populate errors
        allow_any_instance_of(Order).to receive(:save!) do
          raise ActiveRecord::RecordInvalid.new(invalid_order)
        end
        result = OrdersService.create_order_from_cart(user, address.id)
        expect(result[:success]).to be false
        expect(result[:errors]).to be_present
        expect(result[:errors]).to include("Quantity must be greater than 0")
        expect(user.carts.active.count).to eq(1) # Verify rollback
      end
    end
  end

  describe '.fetch_order' do
    let(:order) { create(:order, user: user, book: book) }
    it 'returns the order' do
      result = OrdersService.fetch_order(user, order.id)
      expect(result[:success]).to be true
      expect(result[:order]).to eq(order)
    end

    it 'returns an error for invalid order id' do
      result = OrdersService.fetch_order(user, 9999)
      expect(result[:success]).to be false
      expect(result[:errors]).to eq(["Order not found"])
    end
  end

  describe '.update_order_status' do
    let(:order) { create(:order, user: user, book: book, status: 'pending') }
    context 'with valid status' do
      it 'updates the status' do
        result = OrdersService.update_order_status(user, order.id, 'shipped')
        expect(result[:success]).to be true
        expect(result[:message]).to eq("Order status updated")
        expect(order.reload.status).to eq('shipped')
      end
    end

    context 'with invalid status' do
      it 'returns an error' do
        result = OrdersService.update_order_status(user, order.id, 'invalid')
        expect(result[:success]).to be false
        expect(result[:errors]).to eq(["Invalid status"])
      end
    end

    context 'with invalid order id' do
      it 'returns an error' do
        result = OrdersService.update_order_status(user, 9999, 'shipped')
        expect(result[:success]).to be false
        expect(result[:errors]).to eq(["Order not found"])
      end
    end
  end

  describe '.cancel_order' do
    let(:order) { create(:order, user: user, book: book, status: 'pending') }
    it 'cancels the order' do
      result = OrdersService.cancel_order(user, order.id)
      expect(result[:success]).to be true
      expect(result[:message]).to eq("Order cancelled successfully")
      expect(order.reload.status).to eq('cancelled')
      expect(EmailProducer).to have_received(:publish_email).with("cancel_order_email", hash_including(user_id: user.id))
    end

    context 'when order is already cancelled' do
      it 'returns an error' do
        order.update(status: 'cancelled')
        result = OrdersService.cancel_order(user, order.id)
        expect(result[:success]).to be false
        expect(result[:errors]).to eq(["Order is already cancelled"])
      end
    end

    context 'with invalid order id' do
      it 'returns an error' do
        result = OrdersService.cancel_order(user, 9999)
        expect(result[:success]).to be false
        expect(result[:errors]).to eq(["Order not found"])
      end
    end
  end

  before do
    allow(EmailProducer).to receive(:publish_email)
  end
end