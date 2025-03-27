require 'rails_helper'

RSpec.describe Cart, type: :model do
  let(:user) { create(:user) }
  let(:book) { create(:book, quantity: 5) }
  let(:cart) { build(:cart, user: user, book: book, quantity: 2) }

  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:book) }
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(cart).to be_valid
    end

    context 'presence validations' do
      it { should validate_presence_of(:user_id) }
      it { should validate_presence_of(:book_id) }
    end

    context 'quantity validation' do
      it { should validate_numericality_of(:quantity).is_greater_than_or_equal_to(0) }

      it 'allows quantity of 0' do
        cart.quantity = 0
        expect(cart).to be_valid
      end

      it 'is invalid with a negative quantity' do
        cart.quantity = -1
        expect(cart).not_to be_valid
        expect(cart.errors[:quantity]).to include('must be greater than or equal to 0')
      end

      it 'is invalid with a nil quantity' do
        cart.quantity = nil
        expect(cart).not_to be_valid
        expect(cart.errors[:quantity]).to include('is not a number')
      end
    end
  end

  describe 'scopes' do
    describe '.active' do
      let!(:active_cart) { create(:cart, user: user, book: book, is_deleted: false) }
      let!(:deleted_cart) { create(:cart, user: user, book: book, is_deleted: true) }

      it 'returns only carts where is_deleted is false' do
        expect(Cart.active).to include(active_cart)
        expect(Cart.active).not_to include(deleted_cart)
      end
    end
  end

  describe '#check_stock_availability' do
    context 'when book is present and has sufficient stock' do
      it 'is valid when quantity is less than or equal to book quantity' do
        cart.quantity = 5 # Equal to book.quantity
        expect(cart).to be_valid

        cart.quantity = 3 # Less than book.quantity
        expect(cart).to be_valid
      end
    end

    context 'when book is present but stock is insufficient' do
      it 'is invalid when quantity exceeds book quantity' do
        cart.quantity = 6 # More than book.quantity (5)
        expect(cart).not_to be_valid
        expect(cart.errors[:quantity]).to include('exceeds available stock. Item will be available shortly.')
      end
    end

    context 'when book is not present' do
      it 'does not add errors if book is nil' do
        cart.book = nil
        cart.quantity = 10
        expect(cart).not_to be_valid # Invalid due to book_id presence, not stock
        expect(cart.errors[:quantity]).not_to include('exceeds available stock. Item will be available shortly.')
        expect(cart.errors[:book_id]).to include("can't be blank")
      end
    end

    context 'when book quantity is nil' do
      let(:book_with_nil_stock) { create(:book, quantity: nil) }
      let(:cart_with_nil_stock) { build(:cart, user: user, book: book_with_nil_stock, quantity: 1) }

      it 'does not add errors if book quantity is nil' do
        expect(cart_with_nil_stock).to be_valid
      end
    end

    # Updated test to reflect actual behavior
    context 'when cart quantity is nil' do
      it 'is invalid due to numericality validation' do
        cart.quantity = nil
        expect(cart).not_to be_valid
        expect(cart.errors[:quantity]).to include('is not a number')
      end
    end
  end
end