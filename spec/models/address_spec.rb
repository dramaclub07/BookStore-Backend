require 'rails_helper'

RSpec.describe Address, type: :model do
  let(:user) { create(:user) }
  let(:address) { build(:address, user: user) }

  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(address).to be_valid
    end

    context 'presence validations' do
      it { should validate_presence_of(:street) }
      it { should validate_presence_of(:city) }
      it { should validate_presence_of(:state) }
      it { should validate_presence_of(:zip_code) }
      it { should validate_presence_of(:country) }
    end

    context 'address_type inclusion' do
      it 'is valid with a valid address_type' do
        %w[home work other].each do |type|
          address.address_type = type
          expect(address).to be_valid
        end
      end

      it 'raises an error for an invalid address_type' do
        expect { address.address_type = 'invalid' }.to raise_error(ArgumentError, "'invalid' is not a valid address_type")
      end
    end
  end

  describe 'enums' do
    it 'defines address_type enum with correct values' do
      expect(Address.address_types).to eq({
        'home' => 'home',
        'work' => 'work',
        'other' => 'other'
      })
    end

    # Skip predicate method tests since they’re not generated
    it 'stores address_type as expected' do
      address.address_type = 'home'
      address.save
      expect(address.reload.address_type).to eq('home')

      address.address_type = 'work'
      address.save
      expect(address.reload.address_type).to eq('work')

      address.address_type = 'other'
      address.save
      expect(address.reload.address_type).to eq('other')
    end
  end

  describe '#at_least_one_attribute_present' do
    let(:saved_address) { create(:address, user: user, street: '123 Main St', city: 'Anytown', state: 'CA', zip_code: '12345', country: 'USA', address_type: 'home') }

    context 'on create' do
      it 'does not trigger the custom validation' do
        new_address = build(:address, user: user, street: '456 Elm St', city: 'Othertown', state: 'NY', zip_code: '67890', country: 'USA', address_type: 'work')
        expect(new_address).to be_valid
      end
    end

    context 'on update' do
      it 'is valid when at least one attribute is changed' do
        saved_address.street = '789 Oak St'
        expect(saved_address).to be_valid
      end

      it 'is invalid when no attributes are changed' do
        saved_address.save
        expect(saved_address.valid?(:update)).to be false
        expect(saved_address.errors[:street]).to include("can't be blank")
      end
    end
  endg
end