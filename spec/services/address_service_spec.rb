# spec/services/address_service_spec.rb
require 'rails_helper'

RSpec.describe AddressService do
  let(:user) { create(:user, role: 'user') }
  let(:valid_params) { { street: "123 Main St", city: "Anytown", state: "CA", zip_code: "12345", country: "USA", address_type: "home" } }
  let(:invalid_params) { { street: "" } }

  describe '.get_addresses' do
    let(:cache_key) { "user_#{user.id}_addresses" }

    context 'when addresses are cached' do
      let(:cached_addresses) { [valid_params].to_json }
      before { REDIS.set(cache_key, cached_addresses) }

      it 'returns cached addresses with tokens if present' do
        result = described_class.get_addresses(user)
        expect(result[:success]).to be true
        expect(result[:addresses]).to eq(JSON.parse(cached_addresses))
        
        if result[:access_token].present?
          decoded_access = JwtService.decode_access_token(result[:access_token])
          expect(decoded_access[:user_id]).to eq(user.id)
          expect(decoded_access[:role]).to eq(user.role)
        end
      end
    end


    context 'when addresses are not cached' do
      before { REDIS.del(cache_key) }

      it 'fetches addresses from database, caches them, and returns tokens if present' do
        address = create(:address, user: user)
        result = described_class.get_addresses(user)

        expect(result[:success]).to be true
        expect(result[:addresses].length).to eq(1)
        expect(REDIS.get(cache_key)).to eq([address.as_json].to_json)
      end

    end

  end


  describe '.create_address' do
    it 'creates address, clears cache, and returns tokens if present' do
      result = described_class.create_address(user, valid_params)

      expect(result[:success]).to be true
      expect(result[:address]).to be_present
      expect(REDIS.get("user_#{user.id}_addresses")).to be_nil
      
      if result[:access_token].present?
        decoded_access = JwtService.decode_access_token(result[:access_token])
        expect(decoded_access[:user_id]).to eq(user.id)
      end
    end

    it 'returns errors with invalid params' do
      result = described_class.create_address(user, invalid_params)

      expect(result[:success]).to be false
      expect(result[:errors]).to include("Street can't be blank")
      expect(result[:access_token]).to be_nil
      expect(result[:refresh_token]).to be_nil
    end


    it 'returns errors with invalid params' do

      result = described_class.create_address(user, invalid_params)


      expect(result[:success]).to be false

      expect(result[:errors]).to include("Street can't be blank")

      expect(result[:access_token]).to be_nil

      expect(result[:refresh_token]).to be_nil

    end

  end


  describe '.update_address' do
    let(:address) { create(:address, user: user) }

    context 'with invalid params' do
      it 'returns errors when params are empty' do
        result = described_class.update_address(address, {})

        expect(result[:success]).to be false
        expect(result[:errors]).to include("At least one address attribute must be provided")
        expect(result[:access_token]).to be_nil
      end

      it 'returns errors when params are invalid' do
        result = described_class.update_address(address, invalid_params)

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Street can't be blank")
        expect(result[:refresh_token]).to be_nil
      end
    end

    context 'with valid params' do
      it 'updates address, clears cache, and returns tokens if present' do
        result = described_class.update_address(address, { street: "456 New St" })

        expect(result[:success]).to be true
        expect(result[:address].street).to eq("456 New St")
        expect(REDIS.get("user_#{user.id}_addresses")).to be_nil
      end


      it 'returns errors when params are invalid' do

        result = described_class.update_address(address, invalid_params)


        expect(result[:success]).to be false

        expect(result[:errors]).to include("Street can't be blank")

        expect(result[:refresh_token]).to be_nil

      end

    end


    context 'with valid params' do

      it 'updates address, clears cache, and returns tokens if present' do

        result = described_class.update_address(address, { street: "456 New St" })


        expect(result[:success]).to be true

        expect(result[:address].street).to eq("456 New St")

        expect(REDIS.get("user_#{user.id}_addresses")).to be_nil

      end

    end

  end


  describe '.destroy_address' do
    let(:address) { create(:address, user: user) }

    it 'deletes address, clears cache, and returns tokens if present' do
      result = described_class.destroy_address(address)

      expect(result[:success]).to be true
      expect(result[:message]).to eq("Address deleted successfully")
      expect(REDIS.get("user_#{user.id}_addresses")).to be_nil
      expect(Address.find_by(id: address.id)).to be_nil
    end

    context 'when delete fails' do
      it 'returns error message without tokens' do
        # Create the address instance
        address = create(:address, user: user)
        
        # Stub methods directly on this instance
        allow(address).to receive(:destroy).and_return(false)
        errors_double = double("errors", full_messages: ["Deletion failed"], clear: nil)
        allow(address).to receive(:errors).and_return(errors_double)

        result = described_class.destroy_address(address)

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Failed to delete address")
        expect(result[:access_token]).to be_nil
        expect(result[:refresh_token]).to be_nil
      end
    end
  end

end