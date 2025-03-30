require 'rails_helper'

RSpec.describe AddressService do
  let!(:user) { create(:user) }
  let!(:address) { create(:address, user: user, is_deleted: false) }
  let!(:another_address) { create(:address, user: user, is_deleted: false) }

  before do
    REDIS.del("user_#{user.id}_addresses") # Clear cache before each test
  end

  describe '.get_addresses' do
    context 'when addresses are cached' do
      before do
        REDIS.set("user_#{user.id}_addresses", [address.as_json].to_json)
      end

      it 'returns cached addresses' do
        result = described_class.get_addresses(user)
        expect(result[:success]).to be true
        expect(result[:addresses].size).to eq(1)
        expect(result[:addresses].first['id']).to eq(address.id)
      end
    end

    context 'when addresses are not cached' do
      it 'fetches active addresses from database and caches them' do
        result = described_class.get_addresses(user)
        
        expect(result[:success]).to be true
        expect(result[:addresses].size).to eq(2)
        expect(result[:addresses].map { |a| a['id'] }).to contain_exactly(address.id, another_address.id)
        
        # Verify caching
        cached = REDIS.get("user_#{user.id}_addresses")
        expect(JSON.parse(cached).size).to eq(2)
      end
    end
  end

  describe '.create_address' do
    let(:valid_params) { attributes_for(:address) }

    it 'creates address and clears cache' do
      expect {
        result = described_class.create_address(user, valid_params)
        expect(result[:success]).to be true
        expect(result[:address]).to be_persisted
      }.to change(user.addresses, :count).by(1)
      
      expect(REDIS.get("user_#{user.id}_addresses")).to be_nil
    end
  end

  describe '.update_address' do
    context 'with valid params' do
      it 'updates address and clears cache' do
        result = described_class.update_address(address, city: 'New City')
        expect(result[:success]).to be true
        expect(address.reload.city).to eq('New City')
        expect(REDIS.get("user_#{user.id}_addresses")).to be_nil
      end
    end

    context 'with invalid params' do
      it 'returns errors' do
        result = described_class.update_address(address, street: '')
        expect(result[:success]).to be false
        expect(result[:errors]).to include("Street can't be blank")
      end
    end
  end

  describe '.destroy_address' do
    context 'when soft delete succeeds' do
      it 'marks as deleted and clears cache' do
        result = described_class.destroy_address(address)
        expect(result[:success]).to be true
        expect(address.reload.is_deleted).to be true
        expect(REDIS.get("user_#{user.id}_addresses")).to be_nil
      end
    end

    context 'when soft delete fails' do
      before do
        allow_any_instance_of(Address).to receive(:update).and_return(false)
        address.errors.add(:base, "Deletion failed")
      end

      it 'returns error message' do
        result = described_class.destroy_address(address)
        expect(result[:success]).to be false
        expect(result[:errors]).to include("Deletion failed")
      end
    end
  end
end