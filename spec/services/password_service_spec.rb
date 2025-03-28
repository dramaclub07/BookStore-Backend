require 'rails_helper'

RSpec.describe PasswordService, type: :service do
  let!(:user) { create(:user) }

  describe ".forgot_password" do
    context "when user exists" do
      it "sends an OTP and returns success" do
        allow(UserMailer).to receive_message_chain(:send_otp, :deliver_now)
        result = PasswordService.forgot_password(user.email)

        expect(result[:success]).to be true
        expect(result[:message]).to eq("OTP sent to your email")
        expect(PasswordService::OTP_STORAGE[user.email]).not_to be_nil
      end
    end
    
    context "when user does not exist" do
      it "returns an error" do
        result = PasswordService.forgot_password("nonexistent@example.com")

        expect(result[:success]).to be false
        expect(result[:error]).to eq("User not found")
      end
    end
  end

  describe ".reset_password" do
    before do
      PasswordService::OTP_STORAGE[user.email] = { otp: "123456", otp_expiry: Time.now + 5.minutes }
    end

    context "when OTP is correct and not expired" do
      it "resets the password successfully" do
        result = PasswordService.reset_password(user.email, "123456", "newpassword")

        expect(result[:success]).to be true
        expect(result[:message]).to eq("Password reset successfully")
        expect(PasswordService::OTP_STORAGE[user.email]).to be_nil
        expect(user.reload.authenticate("newpassword")).to be_truthy
      end
    end

    context "when OTP is expired" do
      it "returns an error" do
        PasswordService::OTP_STORAGE[user.email][:otp_expiry] = Time.now - 1.minute
        result = PasswordService.reset_password(user.email, "123456", "newpassword")

        expect(result[:success]).to be false
        expect(result[:error]).to eq("OTP expired")
      end
    end

    context "when OTP is incorrect" do
      it "returns an error" do
        result = PasswordService.reset_password(user.email, "wrongotp", "newpassword")

        expect(result[:success]).to be false
        expect(result[:error]).to eq("Invalid OTP")
      end
    end
  end
end