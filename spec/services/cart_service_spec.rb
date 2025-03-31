require 'rails_helper'

RSpec.describe CartService, type: :service do
  let(:user) { create(:user) }
  let(:book) { create(:book, book_mrp: 100, discounted_price: 80, quantity: 10) }
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
    end

    context 'with valid parameters' do
      it 'adds a new item to the cart' do
        result = service.add_or_update_cart(book.id, 2)
        expect(result[:success]).to be true
        expect(result[:message]).to eq('Cart updated successfully.')
        expect(user.carts.count).to eq(1)
        expect(user.carts.first.quantity).to eq(2)
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

  describe '#remove_cart_item' do # Updated from toggle_cart_item
    let!(:cart) { create(:cart, user: user, book: book, quantity: 1, is_deleted: false) }

    it 'returns error for non-existent item' do
      result = service.remove_cart_item(999)
      expect(result[:success]).to be false
      expect(result[:message]).to eq('Item not found in cart')
    end

    it 'marks the item as deleted' do # Updated from "toggles is_deleted flag"
      result = service.remove_cart_item(book.id)
      expect(result[:success]).to be true
      expect(result[:message]).to eq('Item removed from cart.')
      expect(cart.reload.is_deleted).to be true
    end
  end

  describe '#view_cart' do
    before do
      create(:cart, user: user, book: book, quantity: 2, is_deleted: false)
      create(:cart, user: user, book: create(:book, book_mrp: 50, discounted_price: nil), quantity: 1, is_deleted: false)
      create(:cart, user: user, book: book, quantity: 1, is_deleted: true)
    end

    it 'calculates total price correctly' do
      result = service.view_cart(nil, nil)
      expect(result[:success]).to be true
      expect(result[:cart].length).to eq(2) # Only active items
      expect(result[:total_cart_price]).to eq(210.0) # (2 * 80) + (1 * 50)
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