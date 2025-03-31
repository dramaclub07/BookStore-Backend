require 'rails_helper'

RSpec.describe AddressService do
  let!(:user) { create(:user) }
  let!(:address) { create(:address, user: user, is_deleted: false) }
  let!(:another_address) { create(:address, user: user, is_deleted: false) }
  let(:mock_token) { 'mock_jwt_token' }
  let(:mock_payload) { { 'user_id' => user.id, 'role' => user.role, 'address_updated_at' => Time.now.to_i } }

  before do
    REDIS.del("user_#{user.id}_#{described_class.send(:jwt_fingerprint, user)}_addresses")
    allow(JwtService).to receive(:encode_access_token).and_return(mock_token)
    allow(JwtService).to receive(:decode_access_token).with(mock_token).and_return(mock_payload)
  end

  describe '.get_addresses' do
    context 'when addresses are cached' do
      before do
        REDIS.set("user_#{user.id}_#{described_class.send(:jwt_fingerprint, user)}_addresses", 
                 [address.as_json].to_json)
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
        
        cached = REDIS.get("user_#{user.id}_#{described_class.send(:jwt_fingerprint, user)}_addresses")
        expect(JSON.parse(cached).size).to eq(2)
      end
    end
  end

  describe '.create_address' do
    let(:valid_params) { attributes_for(:address) }

    it 'creates address, clears cache and returns new token' do
      expect {
        result = described_class.create_address(user, valid_params)
        expect(result[:success]).to be true
        expect(result[:address]).to be_persisted
        expect(result[:access_token]).to eq(mock_token)
      }.to change(user.addresses, :count).by(1)
      
      expect(REDIS.get("user_#{user.id}_#{described_class.send(:jwt_fingerprint, user)}_addresses")).to be_nil
    end
  end

  describe '.update_address' do
    context 'with valid params' do
      it 'updates address, clears cache and returns new token' do
        result = described_class.update_address(address, city: 'New City')
        expect(result[:success]).to be true
        expect(address.reload.city).to eq('New City')
        expect(result[:access_token]).to eq(mock_token)
      end
    end

    context 'with invalid params' do
      it 'returns errors without generating new token' do
        result = described_class.update_address(address, street: '')
        expect(result[:success]).to be false
        expect(result[:errors]).to include("Street can't be blank")
        expect(result).not_to have_key(:access_token)
      end
    end
  end

  describe '.destroy_address' do
    context 'when soft delete succeeds' do
      it 'marks as deleted, clears cache and returns new token' do
        result = described_class.destroy_address(address)
        expect(result[:success]).to be true
        expect(address.reload.is_deleted).to be true
        expect(result[:access_token]).to eq(mock_token)
      end
    end

    context 'when soft delete fails' do
      before do
        allow_any_instance_of(Address).to receive(:update).and_return(false)
        allow_any_instance_of(Address).to receive(:errors).and_return(double(full_messages: ["Deletion failed"]))
      end

      it 'returns error message without generating new token' do
        result = described_class.destroy_address(address)
        expect(result[:success]).to be false
        expect(result[:errors]).to include("Deletion failed")
        expect(result).not_to have_key(:access_token)
      end
    end
  end

  describe 'JWT integration' do
    describe '.jwt_fingerprint' do
      it 'generates different fingerprints for different users' do
        user2 = create(:user)
        allow(JwtService).to receive(:encode_access_token)
          .with(hash_including(user_id: user2.id))
          .and_return('different_mock_token')
        
        fp1 = described_class.send(:jwt_fingerprint, user)
        fp2 = described_class.send(:jwt_fingerprint, user2)
        expect(fp1).not_to eq(fp2)
      end
    end

    describe '.refresh_user_token' do
      it 'includes address_updated_at in payload' do
        token = described_class.send(:refresh_user_token, user)
        payload = JwtService.decode_access_token(token)
        expect(payload['address_updated_at']).to be_present
      end
    end
  end
end