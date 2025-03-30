require 'rails_helper'

RSpec.describe CartService do
  let(:user) { create(:user) }
  let(:book) { create(:book, quantity: 10, discounted_price: 15.99) }
  let(:out_of_stock_book) { create(:book, quantity: 0) }
  let(:deleted_book) { create(:book, is_deleted: true) }
  let(:cart_service) { described_class.new(user) }

  describe '#add_or_update_cart' do
    context 'with valid parameters' do
      it 'adds new item to cart' do
        result = cart_service.add_or_update_cart(book.id, 2)
        expect(result[:success]).to be true
        expect(user.carts.count).to eq(1)
      end

      it 'updates existing cart item' do
        create(:cart, user: user, book: book, quantity: 1)
        result = cart_service.add_or_update_cart(book.id, 3)
        expect(result[:success]).to be true
        expect(user.carts.first.quantity).to eq(3)
      end
    end

    context 'with invalid parameters' do
      it 'returns error for invalid book' do
        result = cart_service.add_or_update_cart(999, 1)
        expect(result[:success]).to be false
      end

      it 'returns error for out of stock book' do
        result = cart_service.add_or_update_cart(out_of_stock_book.id, 1)
        expect(result[:success]).to be false
      end

      it 'returns error for deleted book' do
        result = cart_service.add_or_update_cart(deleted_book.id, 1)
        expect(result[:success]).to be false
      end

      it 'returns error for invalid quantity' do
        result = cart_service.add_or_update_cart(book.id, 0)
        expect(result[:success]).to be false
      end
    end
  end

  describe '#update_quantity' do
    let!(:cart_item) { create(:cart, user: user, book: book, quantity: 1) }

    context 'with valid quantity' do
      it 'updates quantity' do
        result = cart_service.update_quantity(book.id, 5)
        expect(result[:success]).to be true
        expect(cart_item.reload.quantity).to eq(5)
      end
    end

    context 'with invalid quantity' do
      it 'returns error for zero quantity' do
        result = cart_service.update_quantity(book.id, 0)
        expect(result[:success]).to be false
      end

      it 'returns error for insufficient stock' do
        result = cart_service.update_quantity(book.id, 999)
        expect(result[:success]).to be false
      end
    end
  end

  describe '#toggle_cart_item' do
    let!(:cart_item) { create(:cart, user: user, book: book) }

    it 'toggles is_deleted flag' do
      result = cart_service.toggle_cart_item(book.id)
      expect(result[:success]).to be true
      expect(cart_item.reload.is_deleted).to be true

      result = cart_service.toggle_cart_item(book.id)
      expect(cart_item.reload.is_deleted).to be false
    end

    it 'returns error for non-existent item' do
      result = cart_service.toggle_cart_item(999)
      expect(result[:success]).to be false
    end
  end

  describe '#view_cart' do
    before do
      create_list(:cart, 3, user: user)
    end

    it 'returns paginated cart items' do
      result = cart_service.view_cart(1, 2)
      expect(result[:success]).to be true
      expect(result[:cart].size).to eq(2)
      expect(result[:pagination][:total_count]).to eq(3)
    end

    it 'calculates total price correctly' do
      result = cart_service.view_cart
      expected_total = user.carts.sum { |c| (c.book.discounted_price || c.book.book_mrp) * c.quantity }
      expect(result[:total_cart_price]).to eq(expected_total)
    end
  end

  describe '#clear_cart' do
    before do
      create_list(:cart, 3, user: user)
    end

    it 'marks all cart items as deleted' do
      result = cart_service.clear_cart
      expect(result[:success]).to be true
      expect(user.carts.active.count).to eq(0)
    end
  end
end