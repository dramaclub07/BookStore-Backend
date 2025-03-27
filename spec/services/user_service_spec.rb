require 'rails_helper'

RSpec.describe UserService do
  describe '.signup' do
    let(:user_params) do
      {
        full_name: 'Akshay Katoch',
        email: 'testuser@gmail.com',
        password: 'Password@123',
        mobile_number: '9876543210'
      }
    end

    context 'when valid parameters are provided' do
      it 'creates a new user and returns a successful result' do
        result = UserService.signup(user_params)

        expect(result).to be_success
        expect(result.user).to be_persisted
        expect(result.error).to be_nil
      end
    end

    context 'when invalid parameters are provided' do
      it 'returns an error if email is missing' do
        user_params[:email] = nil

        result = UserService.signup(user_params)

        expect(result).not_to be_success
        expect(result.error).to include("Email can't be blank")
      end

      it 'returns an error if password is too short' do
        user_params[:password] = '123'

        result = UserService.signup(user_params)

        expect(result).not_to be_success
        expect(result.error).to include("Password is too short")
      end

      it 'returns an error if email is already taken' do
        create(:user, email: user_params[:email])

        result = UserService.signup(user_params)

        expect(result).not_to be_success
        expect(result.error).to include('Email has already been taken')
      end
    end

    context 'when an unexpected error occurs' do
      it 'returns an error message' do
        allow(User).to receive(:new).and_raise(StandardError.new('Unexpected error'))

        result = UserService.signup(user_params)

        expect(result).not_to be_success
        expect(result.error).to include('An unexpected error occurred: Unexpected error')
      end
    end
  end

<<<<<<< HEAD
  describe ".users/login" do
    context "when valid credentials are provided" do
      it "returns success and a token" do
        allow(JwtService).to receive(:encode).and_return("mocked_token")
        result = UserService.users/login(existing_user.email, "Password@123")
=======
  describe '.login' do
    let(:user) { create(:user, password: 'Password@123') }
>>>>>>> 0a8f9a4f46c7cedd6ea0c604f42e444425a7f4ef

    context 'when valid credentials are provided' do
      it 'returns a success result with a token' do
        result = UserService.login(user.email, 'Password@123')

        expect(result).to be_success
        expect(result.user).to eq(user)
        expect(result.token).to be_present
      end
    end

<<<<<<< HEAD
    context "when invalid credentials are provided" do
      it "returns an error" do
        result = UserService.users/login(existing_user.email, "wrongpassword")
        expect(result[:success]).to be false
        expect(result[:error]).to eq("Invalid email or password")
      end
    end
  end
end

RSpec.describe PasswordService, type: :service do
  let!(:existing_user) { create(:user, email: "testuser@gmail.com", password: "Password@123") }
  describe ".users/password/forgot" do
    context "when email exists" do
      it "sends OTP successfully" do
        allow(UserMailer).to receive_message_chain(:send_otp, :deliver_now)
        result = PasswordService.users/password/forgot(existing_user.email)
        expect(result[:success]).to be true
        expect(result[:message]).to eq("OTP sent to your email")
        expect(PasswordService::OTP_STORAGE).to have_key(existing_user.email)
      end
    end

    context "when email does not exist" do
      it "returns an error" do
        result = PasswordService.users/password/forgot("notfound@gmail.com")

        expect(result[:success]).to be false
        expect(result[:error]).to eq("User not found")
      end
    end
  end

  describe ".reset_password" do
    let(:valid_otp) { "123456" }

    before do
      PasswordService::OTP_STORAGE[existing_user.email] = { otp: valid_otp, otp_expiry: Time.now + 5.minutes }
    end

    context "with valid OTP" do
      it "resets the password successfully" do
        result = PasswordService.reset_password(existing_user.email, valid_otp, "NewPassword@123")

        expect(result[:success]).to be true
        expect(result[:message]).to eq("Password reset successfully")
        expect(existing_user.reload.authenticate("NewPassword@123")).to be_truthy
      end
    end

    context "when OTP is incorrect" do
      it "returns an error" do
        result = PasswordService.reset_password(existing_user.email, "654321", "NewPassword@123")

        expect(result[:success]).to be false
        expect(result[:error]).to eq("Invalid OTP")
      end
    end

    context "when OTP is expired" do
      it "returns an error" do
        PasswordService::OTP_STORAGE[existing_user.email][:otp_expiry] = Time.now - 1.minute

        result = PasswordService.reset_password(existing_user.email, valid_otp, "NewPassword@123")

        expect(result[:success]).to be false
        expect(result[:error]).to eq("OTP expired")
      end
    end

    context "when OTP is missing" do
      it "returns an error" do
        PasswordService::OTP_STORAGE.delete(existing_user.email)

        result = PasswordService.reset_password(existing_user.email, valid_otp, "NewPassword@123")

        expect(result[:success]).to be false
        expect(result[:error]).to eq("OTP not found")
=======
    context 'when invalid credentials are provided' do
      it 'returns an error if email is incorrect' do
        result = UserService.login('wrongemail@gmail.com', 'Password@123')

        expect(result).not_to be_success
        expect(result.error).to eq('Invalid email or password')
      end

      it 'returns an error if password is incorrect' do
        result = UserService.login(user.email, 'WrongPassword')

        expect(result).not_to be_success
        expect(result.error).to eq('Invalid email or password')
      end
    end

    context 'when an unexpected error occurs' do
      it 'returns an error message' do
        allow(User).to receive(:find_by).and_raise(StandardError.new('Unexpected error'))

        result = UserService.login(user.email, 'Password@123')

        expect(result).not_to be_success
        expect(result.error).to include('An unexpected error occurred: Unexpected error')
>>>>>>> 0a8f9a4f46c7cedd6ea0c604f42e444425a7f4ef
      end
    end
  end
end
