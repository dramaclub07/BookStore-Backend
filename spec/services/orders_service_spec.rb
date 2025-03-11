require 'rails_helper'

RSpec.describe OrdersService, type: :service do
  let(:user) { create(:user) }
  let(:book) { create(:book, discounted_price: 200, book_mrp: 250) }
  let(:order_params) { { book_id: book.id, quantity: 2 } }

  describe '.create_order' do
    context 'when the book exists' do
      it 'creates an order successfully' do
        result = OrdersService.create_order(user, order_params)
        expect(result[:success]).to be true
        expect(result[:order]).to be_present
      end
    end

    context 'when the book does not exist' do
      it 'returns an error' do
        result = OrdersService.create_order(user, { book_id: nil, quantity: 2 })
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Book not found')
      end
    end
  end
end
