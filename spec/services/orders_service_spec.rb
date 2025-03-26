require 'rails_helper'

RSpec.describe OrdersService, type: :service do
  let(:user) { create(:user) }
  let(:book) { create(:book, discounted_price: 200, book_mrp: 250) }
  let(:address) { create(:address, user: user) }

  describe '.create_order' do
    context 'when all parameters are valid including address_id' do
      let(:order_params) { { book_id: book.id, quantity: 2, address_id: address.id } }

      it 'creates an order successfully with all attributes' do
        result = OrdersService.create_order(user, order_params)
        expect(result[:success]).to be true
        expect(result[:order]).to be_a(Order)
        expect(result[:order].book_id).to eq(book.id)
        expect(result[:order].quantity).to eq(2)
        expect(result[:order].address_id).to eq(address.id)
        expect(result[:order].price_at_purchase).to eq(200)
        expect(result[:order].total_price).to eq(400) # 200 * 2
      end
    end

    context 'when only book_id is provided' do
      let(:order_params) { { book_id: book.id } }

      it 'creates an order with default quantity and no address' do
        result = OrdersService.create_order(user, order_params)
        expect(result[:success]).to be true
        expect(result[:order].quantity).to eq(1)
        expect(result[:order].address_id).to be_nil
        expect(result[:order].total_price).to eq(200) # 200 * 1
      end
    end

    context 'when book does not exist' do
      let(:order_params) { { book_id: 9999, quantity: 2, address_id: address.id } } # Fixed typo here

      it 'returns an error' do
        result = OrdersService.create_order(user, order_params)
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Book not found')
      end
    end

    context 'when book_id is nil' do
      let(:order_params) { { book_id: nil, quantity: 2, address_id: address.id } }

      it 'returns an error' do
        result = OrdersService.create_order(user, order_params)
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Book not found')
      end
    end

    context 'when quantity is not provided' do
      let(:order_params) { { book_id: book.id, address_id: address.id } }

      it 'creates an order with quantity defaulting to 1' do
        result = OrdersService.create_order(user, order_params)
        expect(result[:success]).to be true
        expect(result[:order].quantity).to eq(1)
        expect(result[:order].total_price).to eq(200) # 200 * 1
      end
    end

    context 'when quantity is a string' do
      let(:order_params) { { book_id: book.id, quantity: "3", address_id: address.id } }

      it 'converts string quantity to integer' do
        result = OrdersService.create_order(user, order_params)
        expect(result[:success]).to be true
        expect(result[:order].quantity).to eq(3)
        expect(result[:order].total_price).to eq(600) # 200 * 3
      end
    end

    context 'when quantity is a float' do
      let(:order_params) { { book_id: book.id, quantity: 2.7, address_id: address.id } }

      it 'converts float quantity to integer' do
        result = OrdersService.create_order(user, order_params)
        expect(result[:success]).to be true
        expect(result[:order].quantity).to eq(2) # to_i truncates to 2
        expect(result[:order].total_price).to eq(400) # 200 * 2
      end
    end

    context 'when quantity is zero' do
      let(:order_params) { { book_id: book.id, quantity: 0, address_id: address.id } }

      it 'fails due to model validation' do
        result = OrdersService.create_order(user, order_params)
        expect(result[:success]).to be false
        expect(result[:error]).to include("Quantity must be greater than 0")
      end
    end

    context 'when quantity is negative' do
      let(:order_params) { { book_id: book.id, quantity: -1, address_id: address.id } }

      it 'fails due to model validation' do
        result = OrdersService.create_order(user, order_params)
        expect(result[:success]).to be false
        expect(result[:error]).to include("Quantity must be greater than 0")
      end
    end

    context 'when quantity is a non-numeric string' do
      let(:order_params) { { book_id: book.id, quantity: "invalid", address_id: address.id } }

      it 'fails due to model validation' do
        result = OrdersService.create_order(user, order_params)
        expect(result[:success]).to be false
        expect(result[:error]).to include("Quantity is not a number")
      end
    end

    context 'when book has no discounted_price' do
      let(:book) { create(:book, discounted_price: nil, book_mrp: 250) }
      let(:order_params) { { book_id: book.id, quantity: 2, address_id: address.id } }

      it 'uses book_mrp as price_at_purchase' do
        result = OrdersService.create_order(user, order_params)
        expect(result[:success]).to be true
        expect(result[:order].price_at_purchase).to eq(250)
        expect(result[:order].total_price).to eq(500) # 250 * 2
      end
    end

    context 'when address_id is provided but invalid' do
      let(:order_params) { { book_id: book.id, quantity: 2, address_id: 9999 } }

      it 'returns an error for invalid address' do
        result = OrdersService.create_order(user, order_params)
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Address not found')
      end
    end

    context 'when address_id is nil' do
      let(:order_params) { { book_id: book.id, quantity: 2, address_id: nil } }

      it 'creates an order with nil address_id' do
        result = OrdersService.create_order(user, order_params)
        expect(result[:success]).to be true
        expect(result[:order].address_id).to be_nil
        expect(result[:order].total_price).to eq(400) # 200 * 2
      end
    end

    context 'when order_params include extra attributes' do
      let(:order_params) { { book_id: book.id, quantity: 2, address_id: address.id, status: 'shipped', invalid_field: 'test' } }

      it 'ignores unpermitted attributes and creates order with default status' do
        result = OrdersService.create_order(user, order_params)
        expect(result[:success]).to be true
        expect(result[:order].quantity).to eq(2)
        expect(result[:order].address_id).to eq(address.id)
        expect(result[:order].attributes).not_to include('invalid_field')
        expect(result[:order].status).to eq('pending') # Default value from model
      end
    end

    context 'when user is nil' do
      let(:order_params) { { book_id: book.id, quantity: 2, address_id: address.id } }

      it 'raises an error if user is not provided' do
        expect {
          OrdersService.create_order(nil, order_params)
        }.to raise_error(NoMethodError, /undefined method `orders' for nil/)
      end
    end

    context 'when order validations fail due to missing required field' do
      let(:order_params) { { book_id: book.id, quantity: 2 } }

      before do
        allow_any_instance_of(Order).to receive(:valid?).and_return(false)
        allow_any_instance_of(Order).to receive(:errors).and_return(double(full_messages: ["Address can't be blank"]))
      end

      it 'returns validation errors' do
        result = OrdersService.create_order(user, order_params)
        expect(result[:success]).to be false
        expect(result[:error]).to include("Address can't be blank")
      end
    end

    context 'when database save fails' do
      let(:order_params) { { book_id: book.id, quantity: 2, address_id: address.id } }

      before do
        allow_any_instance_of(Order).to receive(:save).and_return(false)
        allow_any_instance_of(Order).to receive(:errors).and_return(double(full_messages: ["Database error"]))
      end

      it 'returns an error' do
        result = OrdersService.create_order(user, order_params)
        expect(result[:success]).to be false
        expect(result[:error]).to eq(["Database error"])
      end
    end

    context 'when quantity is very large' do
      let(:order_params) { { book_id: book.id, quantity: 1_000_000, address_id: address.id } }

      it 'handles large quantities correctly' do
        result = OrdersService.create_order(user, order_params)
        expect(result[:success]).to be true
        expect(result[:order].quantity).to eq(1_000_000)
        expect(result[:order].total_price).to eq(200_000_000) # 200 * 1,000,000
      end
    end
  end
end