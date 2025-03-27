require 'rails_helper'

RSpec.describe Order, type: :model do
  let(:user) { create(:user) }
  let(:book) { create(:book, book_mrp: 100, discounted_price: 80) }
  let(:address) { create(:address, user: user) }
  let(:order) { build(:order, user: user, book: book, address: address, quantity: 2, price_at_purchase: 80) }

  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:book) }
    it { should belong_to(:address).optional }
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(order).to be_valid
    end

    context 'quantity validation' do
      it { should validate_numericality_of(:quantity).is_greater_than(0) }

      it 'is invalid with quantity of 0' do
        order.quantity = 0
        expect(order).not_to be_valid
        expect(order.errors[:quantity]).to include('must be greater than 0')
      end

      it 'is invalid with a negative quantity' do
        order.quantity = -1
        expect(order).not_to be_valid
        expect(order.errors[:quantity]).to include('must be greater than 0')
      end

      it 'is invalid with a nil quantity' do
        order.quantity = nil
        expect(order).not_to be_valid
        expect(order.errors[:quantity]).to include('is not a number')
      end
    end

    context 'price_at_purchase validation' do
      it { should validate_numericality_of(:price_at_purchase).is_greater_than_or_equal_to(0) }

      it 'allows price_at_purchase of 0' do
        order.price_at_purchase = 0
        expect(order).to be_valid
      end

      it 'is invalid with a negative price_at_purchase' do
        order.price_at_purchase = -1
        expect(order).not_to be_valid
        expect(order.errors[:price_at_purchase]).to include('must be greater than or equal to 0')
      end

      it 'is invalid with a nil price_at_purchase' do
        order.price_at_purchase = nil
        expect(order).not_to be_valid
        expect(order.errors[:price_at_purchase]).to include('is not a number')
      end
    end

    context 'total_price validation' do
      it { should validate_numericality_of(:total_price).is_greater_than_or_equal_to(0) }

      it 'allows total_price of 0' do
        order.price_at_purchase = 0
        order.quantity = 1
        order.valid? # Trigger calculate_total_price
        expect(order.total_price).to eq(0)
        expect(order).to be_valid
      end

      it 'is invalid with a negative total_price' do
        order.price_at_purchase = nil # Prevent calculate_total_price from overwriting
        order.total_price = -1
        expect(order).not_to be_valid
        expect(order.errors[:total_price]).to include('must be greater than or equal to 0') # Fixed typo
      end
    end

    context 'status validation' do
      it { should validate_presence_of(:status) }

      it 'is valid with an allowed status' do
        %w[pending processing shipped delivered cancelled].each do |status|
          order.status = status
          expect(order).to be_valid
        end
      end

      it 'is invalid with an invalid status' do
        order.status = 'invalid'
        expect(order).not_to be_valid
        expect(order.errors[:status]).to include('is not included in the list')
      end

      it 'is invalid with a nil status' do
        order.status = nil
        expect(order).not_to be_valid
        expect(order.errors[:status]).to include("can't be blank")
      end
    end
  end

  describe '#calculate_total_price' do
    context 'when price_at_purchase and quantity are present' do
      it 'calculates total_price correctly' do
        order.quantity = 2
        order.price_at_purchase = 80
        order.valid? # Trigger before_validation
        expect(order.total_price).to eq(160)
      end

      it 'sets total_price to 0 when price_at_purchase is 0' do
        order.quantity = 3
        order.price_at_purchase = 0
        order.valid? # Trigger before_validation
        expect(order.total_price).to eq(0)
      end
    end

    context 'when price_at_purchase is nil' do
      it 'does not calculate total_price' do
        order.price_at_purchase = nil
        order.total_price = 200
        order.valid? # Trigger before_validation
        expect(order.total_price).to eq(200) # Unchanged
      end
    end

    context 'when quantity is nil' do
      it 'does not calculate total_price' do
        order.quantity = nil
        order.price_at_purchase = 80
        order.total_price = 200
        order.valid? # Trigger before_validation
        expect(order.total_price).to eq(200) # Unchanged, but invalid due to quantity
        expect(order.errors[:quantity]).to include('is not a number')
      end
    end
  end
end