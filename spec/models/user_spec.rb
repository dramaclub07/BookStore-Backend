# spec/models/user_spec.rb
require 'rails_helper'

RSpec.describe User, type: :model do
  let(:user) { build(:user) }

  describe 'associations' do
    it { should have_many(:wishlists) }
    it { should have_many(:carts).dependent(:destroy) }
    it { should have_many(:orders).dependent(:destroy) }
    it { should have_many(:addresses).dependent(:destroy) }
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(user).to be_valid
    end

    context 'full_name validation' do
      it { should validate_presence_of(:full_name) }
      it { should validate_length_of(:full_name).is_at_least(3).is_at_most(50) }

      it 'is invalid with a full_name shorter than 3 characters' do
        user.full_name = 'Ab'
        expect(user).not_to be_valid
        expect(user.errors[:full_name]).to include('is too short (minimum is 3 characters)')
      end

      it 'is invalid with a full_name longer than 50 characters' do
        user.full_name = 'A' * 51
        expect(user).not_to be_valid
        expect(user.errors[:full_name]).to include('is too long (maximum is 50 characters)')
      end
    end

    context 'email validation' do
    #   it { should validate_presence_of(:email) }
    #   it { should validate_uniqueness_of(:email).case_insensitive }

      it 'is valid with a gmail.com email' do
        user.email = 'test@gmail.com'
        expect(user).to be_valid
      end

      it 'is valid with a yahoo.com email' do
        user.email = 'test@yahoo.com'
        expect(user).to be_valid
      end

      it 'is valid with an outlook.com email' do
        user.email = 'test@outlook.com'
        expect(user).to be_valid
      end

      it 'is invalid with an unsupported email domain' do
        user.email = 'test@other.com'
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include('is invalid')
      end

      it 'is invalid with a malformed email' do
        user.email = 'invalid-email'
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include('is invalid')
      end
    end

    context 'mobile_number validation' do
      it 'requires presence unless social login' do
        user.mobile_number = nil
        expect(user).not_to be_valid
        expect(user.errors[:mobile_number]).to include("can't be blank")

        user.google_id = '12345'
        user.mobile_number = nil
        expect(user).to be_valid
      end

      it 'requires uniqueness unless social login' do
        create(:user, mobile_number: '9123456789')
        user.mobile_number = '9123456789'
        expect(user).not_to be_valid
        expect(user.errors[:mobile_number]).to include('has already been taken')

        user.google_id = '12345'
        expect(user).to be_valid
      end

      it 'is valid with a 10-digit mobile number starting with 6, 7, 8, or 9' do
        %w[6123456789 7123456789 8123456789 9123456789].each do |number|
          user.mobile_number = number
          expect(user).to be_valid
        end
      end

      it 'is invalid with a mobile number not starting with 6, 7, 8, or 9' do
        user.mobile_number = '5123456789'
        expect(user).not_to be_valid
        expect(user.errors[:mobile_number]).to include('is invalid')
      end

      it 'is invalid with a mobile number shorter than 10 digits' do
        user.mobile_number = '912345678'
        expect(user).not_to be_valid
        expect(user.errors[:mobile_number]).to include('is invalid')
      end

      it 'is invalid with a mobile number longer than 10 digits' do
        user.mobile_number = '91234567890'
        expect(user).not_to be_valid
        expect(user.errors[:mobile_number]).to include('is invalid')
      end

      it 'is invalid with a non-numeric mobile number' do
        user.mobile_number = '91234abcde'
        expect(user).not_to be_valid
        expect(user.errors[:mobile_number]).to include('is invalid')
      end
    end

    context 'password validation' do
      it 'requires presence unless social login' do
        user.password = nil
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include("can't be blank")

        user.google_id = '12345'
        user.password = nil
        expect(user).to be_valid
      end

      it 'requires minimum length of 6 unless social login' do
        user.password = 'pass'
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include('is too short (minimum is 6 characters)')

        user.google_id = '12345'
        user.password = 'pass'
        expect(user).to be_valid
      end
    end

    context 'social login' do
      let(:google_user) { build(:user, google_id: '12345', password: nil, mobile_number: nil) }
      let(:facebook_user) { build(:user, facebook_id: '54321', password: nil, mobile_number: nil) }

      it 'is valid without password and mobile_number for Google login' do
        expect(google_user).to be_valid
      end

      it 'is valid without password and mobile_number for Facebook login' do
        expect(facebook_user).to be_valid
      end

      it 'is invalid without password if not a social login' do
        user.password = nil
        user.google_id = nil
        user.facebook_id = nil
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include("can't be blank")
      end

      it 'is invalid without mobile_number if not a social login' do
        user.mobile_number = nil
        user.google_id = nil
        user.facebook_id = nil
        expect(user).not_to be_valid
        expect(user.errors[:mobile_number]).to include("can't be blank")
      end
    end
  end

  describe 'has_secure_password' do
    it 'sets password_digest when password is set' do
      user.password = 'NewPassword@123'
      user.save
      expect(user.password_digest).to be_present
    end

    it 'authenticates with correct password' do
      user.save
      expect(user.authenticate('Password@123')).to be_truthy
    end

    it 'does not authenticate with incorrect password' do
      user.save
      expect(user.authenticate('WrongPassword')).to be_falsey
    end
  end
end