require 'rails_helper'

RSpec.describe UserService, type: :service do
  let!(:existing_user) { create(:user, password: 'Password@123') }
  describe ".signup" do
    context "when valid details are provided" do
      it "creates a new user successfully" do
        params = attributes_for(:user, email: Faker::Internet.unique.email(domain: "gmail.com"), password: "NewPass@123")

        result = UserService.signup(params)
    
  
    
        expect(result[:success]).to be true
        expect(result[:user]).to be_present
        expect(result[:user].email).to eq(params[:email])
      end
    end

    context "when email is already taken" do
      it "returns an error" do
        params = attributes_for(:user, email: existing_user.email, password: "AnotherPass@123") # No user: key
        result = UserService.signup(params)

        expect(result[:success]).to be false
        expect(result[:error]).to include("Email has already been taken")
      end
    end
  end

  describe ".login" do
    context "when valid credentials are provided" do
      it "returns success and a token" do
        allow(JwtService).to receive(:encode).and_return("mocked_token")
        result = UserService.login(existing_user.email, "Password@123")

        expect(result[:success]).to be true
        expect(result[:token]).to eq("mocked_token")
      end
    end

    context "when invalid credentials are provided" do
      it "returns an error" do
        result = UserService.login(existing_user.email, "wrongpassword")

        expect(result[:success]).to be false
        expect(result[:error]).to eq("Invalid email or password")
      end
    end
  end
end

RSpec.describe PasswordService, type: :service do
  let!(:existing_user) { create(:user, email: "testuser@gmail.com", password: "Password@123") }

  describe ".forgot_password" do
    context "when email exists" do
      it "sends OTP successfully" do
        allow(UserMailer).to receive_message_chain(:send_otp, :deliver_now)
        
        result = PasswordService.forgot_password(existing_user.email)

        expect(result[:success]).to be true
        expect(result[:message]).to eq("OTP sent to your email")
        expect(PasswordService::OTP_STORAGE).to have_key(existing_user.email)
      end
    end

    context "when email does not exist" do
      it "returns an error" do
        result = PasswordService.forgot_password("notfound@gmail.com")

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
      end
    end
  end
end