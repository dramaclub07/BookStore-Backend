require 'rails_helper'

RSpec.describe AddressService do
  let!(:user) { create(:user) }
  let!(:address) { create(:address, user: user) }
  let!(:another_address) { create(:address, user: user) }

  describe '.get_addresses' do
    context 'when addresses are cached' do
      before do
        cache_key = "user_#{user.id}_addresses"
        REDIS.set(cache_key, [address.as_json].to_json)
      end

      it 'returns cached addresses' do
        result = AddressService.get_addresses(user)
        expect(result[:success]).to be true
        expect(result[:addresses].size).to eq(1)
        expect(result[:addresses].first['id']).to eq(address.id)
      end
    end
    context 'when addresses are not cached' do
      it 'fetches addresses from the database and caches them' do
       
        result = AddressService.get_addresses(user)
        expect(result[:success]).to be true
        expect(result[:addresses].size).to eq(2)
        expect(result[:addresses].map { |a| a['id'] }).to include(address.id, another_address.id)
      end
    end
  end

  describe '.create_address' do
    context 'when address is valid' do
      let(:valid_params) { { street: '123 Main St', city: 'Anytown', state: 'CA', zip_code: '12345', country: 'USA' } }

      it 'creates a new address and invalidates the cache' do
        result = AddressService.create_address(user, valid_params)
        expect(result[:success]).to be true
        expect(result[:address].street).to eq('123 Main St')
        expect(REDIS.get("user_#{user.id}_addresses")).to be_nil
      end
    end

    context 'when address is invalid' do
      let(:invalid_params) { { street: '' } }

      it 'returns validation errors' do
        result = AddressService.create_address(user, invalid_params)
        expect(result[:success]).to be false
        expect(result[:errors]).to include("Street can't be blank")
      end
    end
  end

  describe '.update_address' do
    context 'when address is valid' do
      let(:valid_params) { { city: 'New City' } }

      it 'updates the address and invalidates the cache' do
        result = AddressService.update_address(address, valid_params)
        expect(result[:success]).to be true
        expect(result[:address].city).to eq('New City')
        expect(REDIS.get("user_#{user.id}_addresses")).to be_nil
      end
    end

    context 'when address is invalid' do
      let(:invalid_params) { { street: '' } }

      it 'returns validation errors' do
        result = AddressService.update_address(address, invalid_params)
        expect(result[:success]).to be false
        expect(result[:errors]).to include("Street can't be blank")
      end
    end

    context 'when params are blank' do
      let(:blank_params) { {} }

      it 'returns an error message' do
        result = AddressService.update_address(address, blank_params)
        expect(result[:success]).to be false
        expect(result[:errors]).to include("At least one address attribute must be provided")
      end
    end
  end

  describe '.destroy_address' do
    context 'when address is successfully destroyed' do
      it 'deletes the address and invalidates the cache' do
        result = AddressService.destroy_address(address)
        expect(result[:success]).to be true
        expect(result[:message]).to eq('Address deleted successfully')
        expect(REDIS.get("user_#{user.id}_addresses")).to be_nil
      end
    end

    context 'when address cannot be destroyed' do
      before do
        allow(address).to receive(:destroy).and_return(false)
      end

      it 'returns an error message' do
        result = AddressService.destroy_address(address)
        expect(result[:success]).to be false
        expect(result[:errors]).to include('Failed to delete address')
      end
    end
  end
end