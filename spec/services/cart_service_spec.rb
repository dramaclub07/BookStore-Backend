# spec/services/cart_service_spec.rb
require 'rails_helper'

RSpec.describe CartService, type: :service do
  let(:user) { create(:user) }
  let(:book) { create(:book, book_mrp: 100, discounted_price: 80, quantity: 10, is_deleted: false, out_of_stock: false) }
  let(:service) { CartService.new(user) }

  describe '#add_or_update_cart' do
    context 'with invalid parameters' do
      it 'returns error for invalid quantity' do
        result = service.add_or_update_cart(book.id, 0)
        expect(result[:success]).to be false
        expect(result[:message]).to eq('Invalid quantity.')
      end

      it 'returns error for negative quantity' do
        result = service.add_or_update_cart(book.id, -1)
        expect(result[:success]).to be false
        expect(result[:message]).to eq('Invalid quantity.')
      end

      it 'returns error for non-existent book' do
        result = service.add_or_update_cart(999, 1)
        expect(result[:success]).to be false
        expect(result[:message]).to eq('Book not found or unavailable.')
      end

      it 'returns error when book is out of stock' do
        out_of_stock_book = create(:book, out_of_stock: true)
        result = service.add_or_update_cart(out_of_stock_book.id, 1)
        expect(result[:success]).to be false
        expect(result[:message]).to eq('Book not found or unavailable.')
      end

      it 'returns error when quantity exceeds stock' do
        result = service.add_or_update_cart(book.id, 11)
        expect(result[:success]).to be false
        expect(result[:message]).to eq('Not enough stock available.')
      end
    end

    context 'with valid parameters' do
      it 'adds a new item to the cart' do
        result = service.add_or_update_cart(book.id, 2)
        expect(result[:success]).to be true
        expect(result[:message]).to eq('Cart updated successfully.')
        expect(user.carts.count).to eq(1)
        expect(user.carts.first.quantity).to eq(2)
        expect(user.carts.first.is_deleted).to be false
      end

      it 'updates an existing item in the cart' do
        create(:cart, user: user, book: book, quantity: 1, is_deleted: false)
        result = service.add_or_update_cart(book.id, 3)
        expect(result[:success]).to be true
        expect(result[:message]).to eq('Cart updated successfully.')
        expect(user.carts.count).to eq(1)
        expect(user.carts.first.quantity).to eq(3)
      end
    end
  end

  describe '#update_quantity' do
    let!(:cart) { create(:cart, user: user, book: book, quantity: 1, is_deleted: false) }

    context 'with invalid quantity' do
      it 'returns error for zero quantity' do
        result = service.update_quantity(book.id, 0)
        expect(result[:success]).to be false
        expect(result[:message]).to eq('Invalid quantity.')
      end

      it 'returns error for negative quantity' do
        result = service.update_quantity(book.id, -1)
        expect(result[:success]).to be false
        expect(result[:message]).to eq('Invalid quantity.')
      end

      it 'returns error for non-existent cart item' do
        result = service.update_quantity(999, 1)
        expect(result[:success]).to be false
        expect(result[:message]).to eq('Item not found in cart')
      end

      it 'returns error when quantity exceeds stock' do
        result = service.update_quantity(book.id, 11)
        expect(result[:success]).to be false
        expect(result[:message]).to eq('Not enough stock available.')
      end
    end

    context 'with valid quantity' do
      it 'updates the quantity successfully' do
        result = service.update_quantity(book.id, 3)
        expect(result[:success]).to be true
        expect(result[:message]).to eq('Quantity updated successfully.')
        expect(cart.reload.quantity).to eq(3)
      end
    end
  end

  describe '#toggle_cart_item' do
    let!(:cart) { create(:cart, user: user, book: book, quantity: 1, is_deleted: false) }

    it 'returns error for non-existent item' do
      result = service.toggle_cart_item(999)
      expect(result[:success]).to be false
      expect(result[:message]).to eq('Item not found in cart')
    end

    it 'marks an active item as deleted' do
      result = service.toggle_cart_item(book.id)
      expect(result[:success]).to be true
      expect(result[:message]).to eq('Item removed from cart.')
      expect(cart.reload.is_deleted).to be true
    end

    it 'restores a deleted item' do
      cart.update(is_deleted: true)
      result = service.toggle_cart_item(book.id)
      expect(result[:success]).to be true
      expect(result[:message]).to eq('Item restored from cart.')
      expect(cart.reload.is_deleted).to be false
    end
  end

  describe '#view_cart' do
    before do
      create(:cart, user: user, book: book, quantity: 2, is_deleted: false)
      create(:cart, user: user, book: create(:book, book_mrp: 50, discounted_price: nil, quantity: 5), quantity: 1, is_deleted: false)
      create(:cart, user: user, book: book, quantity: 1, is_deleted: true)
    end

    it 'calculates total price correctly' do
      result = service.view_cart(nil, nil)
      expect(result[:success]).to be true
      expect(result[:cart].length).to eq(2) # Only active items
      expect(result[:total_cart_price]).to eq(210.0) # (2 * 80) + (1 * 50)
      expect(result[:cart].first[:book_id]).to eq(book.id)
      expect(result[:cart].first[:quantity]).to eq(2)
      expect(result[:cart].first[:total_price]).to eq(160.0)
    end
  end

  describe '#clear_cart' do
    before do
      create(:cart, user: user, book: book, quantity: 1, is_deleted: false)
      create(:cart, user: user, book: book, quantity: 2, is_deleted: false)
      create(:cart, user: user, book: book, quantity: 3, is_deleted: true)
    end

    it 'marks all cart items as deleted' do
      result = service.clear_cart
      expect(result[:success]).to be true
      expect(result[:message]).to eq('Cart cleared successfully.')
      expect(user.carts.where(is_deleted: false).count).to eq(0)
      expect(user.carts.where(is_deleted: true).count).to eq(3)
    end
  end
end